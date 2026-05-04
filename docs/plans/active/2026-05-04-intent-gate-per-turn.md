# Per-turn intent-capture gate (todo-Bash + UserPromptSubmit invalidation)

## Context

The intent-capture gate v4.1 (PR #51, mergeado) bloquea Edit/Write sin marker confirmado, pero deja dos huecos críticos:

1. **Bash no gateado.** El `pre-edit-intent-gate.sh` solo registra el matcher `Write|Edit|MultiEdit|NotebookEdit`. Operaciones como `git commit`, `git push`, `gh pr create`, `rm`, `mv` pasan sin marker — exactamente las acciones que más necesitan confirmación.

2. **Marker de 60 minutos comparte sesión.** El `find -mmin -60` permite que múltiples turnos del operador reusen la misma confirmación. Operador pide X (grill, confirmo, marker), 30 min después pide Y completamente distinto, agente actúa sin re-grill — el marker sigue fresco.

El operador validó:
- `gate-all-Bash` (estricto): todo Bash requiere marker, incluyendo `git status`/`ls`/`grep`. Coherente con "nada es trivial". Bypass por `BATUTA_INTENT_BYPASS=1`.
- Marker debe invalidarse **al inicio de cada turno del operador**, no por ventana de tiempo. La unidad real es el turn boundary (operador → agente → operador).

Outcome buscado: cada turno del operador arranca con marker limpio → agente está obligado a re-correr `intent-capture` (grill → capture → confirm) antes de cualquier Edit/Write/Bash. Subagentes siguen bypaseando por `agent_id`. `BATUTA_INTENT_BYPASS=1` sigue siendo el override operador-side.

## Mecanismo

**UserPromptSubmit hook** dispara cuando el operador envía un prompt, antes de que el agente lo procese. Este hook borra todos los markers `.intent-confirmed-*` del project root. Resultado: el agente nunca ve un marker heredado del turno anterior; debe volver a grillar.

**PreToolUse Bash matcher** extiende `pre-edit-intent-gate.sh` para gatear cualquier tool call de Bash. Sin file_path → salta la lógica de exempt-paths → va directo al chequeo del marker.

## Archivos a modificar

### 1. NEW: `hooks/clear-intent-marker.sh`
- Hook UserPromptSubmit. Resuelve project root vía `$CLAUDE_PROJECT_DIR` (variable que Claude Code expone) o walk-up `.git/`.
- Borra `<project-root>/.claude/.intent-confirmed-*` (`rm -f`, glob).
- Fail-soft: `set +e`, log a `.claude/kb-debug.log`, exit 0 SIEMPRE. Un fallo en cleanup nunca bloquea la sesión.
- Patrón a seguir: `hooks/session-start.sh` (mismo estilo de fail-soft + logging).

### 2. MODIFY: `hooks/pre-edit-intent-gate.sh`
- Detectar `tool_name` temprano. Si `Bash`:
  - Saltar la rama de `tool_input.file_path` y exempt-paths.
  - Resolver project root via `$CLAUDE_PROJECT_DIR` con fallback a `git -C "$PWD" rev-parse --show-toplevel`.
  - Aplicar el mismo orden: `BATUTA_INTENT_BYPASS=1` check → marker check → bloquear con mensaje específico para Bash.
- Mantener la rama Edit/Write existente intacta (file_path-based exempt-paths).
- Eliminar la ventana `-mmin -60`. El marker existe o no existe — el cleanup hook se encarga de la frescura. Reemplazar por simple `find -name '.intent-confirmed-*' -print -quit`.
- Subagent bypass (`agent_id`) y path-traversal guard inalterados.

### 3. MODIFY: `hooks/hooks.json`
- Nueva entrada `UserPromptSubmit` (sin matcher, dispara siempre):
  ```json
  "UserPromptSubmit": [
    { "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/clear-intent-marker.sh", "timeout": 5 }] }
  ]
  ```
- Agregar matcher `Bash` al array PreToolUse, apuntando a `pre-edit-intent-gate.sh`. El matcher actual `Bash` ya tiene `pr-merge-guard.sh`; agregar el intent-gate **después** (orden: pr-merge primero por ser el bloqueo más específico).

### 4. MODIFY: `skills/intent-capture/SKILL.md`
- **Step 1 (Detect)**: agregar nota: "Cada turno del operador arranca con marker limpio (UserPromptSubmit lo invalidó). Tratá cada turno como potencial nuevo ask. Excepción única: confirmaciones cortas a un intent en progreso ('sí', 'dale', 'procedé') — esas no inician un nuevo grill."
- **Step 5 (Confirm)**: aclarar el alcance del marker: "El marker autoriza Edit/Write/Bash hasta el próximo prompt del operador. UserPromptSubmit lo borra automáticamente al inicio del siguiente turno."

### 5. MODIFY: `rules/core/intent-capture-required.md`
- **Rule 3**: reescribir. De "valid for 60 minutes from its mtime" → "valid until the next UserPromptSubmit (next operator turn). The hook `clear-intent-marker.sh` deletes all `.intent-confirmed-*` markers before the agent processes a new prompt. There is no time-based expiration — the boundary is the operator turn, not the clock."
- **Rule 5**: invertir. De "gate does NOT apply to Bash" → "gate applies to ALL Bash tool calls. No allow-list of read-only commands; no deny-list of mutating patterns. Distinguir read-only de mutante en shell es heurístico y frágil — es más simple y correcto gatear todo. Para reads triviales el operador usa `BATUTA_INTENT_BYPASS=1` al lanzar la sesión."

### 6. MODIFY: `CLAUDE.md` (proyecto)
- Sección `### intent-capture (enforced)`: actualizar el párrafo "Enforcement (v4.1)" → "Enforcement (v4.2)". Mencionar:
  - Hook `clear-intent-marker.sh` invalida markers en cada UserPromptSubmit.
  - Gate ahora aplica también a Bash.
  - Sin ventana de tiempo — el límite es el turn boundary.

### 7. MODIFY: `~/.claude/CLAUDE.md` (global, fuera del repo)
- Sección "Intent capture (pre-execution gate)" → bullet "Intent-capture gate (MUST-C)": actualizar para reflejar v4.2 (turn-boundary + Bash coverage).
- Sección "Engineering invariants from `rules/`": actualizar la línea "New rule shipped in v4.1" para que diga "v4.2: per-turn invalidation + Bash coverage. See `rules/core/intent-capture-required.md`."

## Patrones a reutilizar

- **Fail-soft logging**: `hooks/session-start.sh` líneas 1–30 (uso de `set +e`, `trap`, kb-debug.log).
- **Project root resolution**: `hooks/pre-edit-intent-gate.sh` líneas 77–94 (walk-up `.git/`).
- **Path-traversal guard**: `hooks/pre-edit-intent-gate.sh` líneas 56–60.
- **Subagent detection**: `hooks/pre-edit-intent-gate.sh` líneas 41–46 (`agent_id` + `hook_event_name == "PreToolUse"`).
- **JSON parse fail-soft**: todos los hooks existentes — `if ! command -v jq → exit 0 con warning`.

## Verificación end-to-end

1. **Boot test (sin marker)**: sesión nueva, no hay marker. `operator> "ejecutá ls"` → hook bloquea Bash, agente debe correr `intent-capture` primero.
2. **Happy path**: `operator> "agregá retry al payment service"` → grill → confirm → marker escrito → Edit/Write proceden → agente termina turno.
3. **Per-turn invalidation**: en la misma sesión, después del paso 2, `operator> "ahora agregá logging"` → UserPromptSubmit borra marker → primer Edit/Write/Bash bloqueado → agente debe re-grillar.
4. **Subagent bypass**: durante un turno con marker fresco, agente delega a `implementer` → subagent ejecuta Bash/Edit sin nuevo grill (agent_id bypass).
5. **Bypass env var**: `BATUTA_INTENT_BYPASS=1 claude` → todos los gates permiten, log entries en `.claude/kb-debug.log`.
6. **Fail-soft cleanup**: simular fallo en `clear-intent-marker.sh` (e.g., quitar permisos de ejecución) → sesión sigue funcionando, marker viejo se queda hasta próximo turno OK.
7. **Validación estática**: `bash -n hooks/clear-intent-marker.sh` y `bash -n hooks/pre-edit-intent-gate.sh` sin errores. `python3 -c "import json; json.load(open('hooks/hooks.json'))"` parsea OK.
8. **Audit chain post-edit**: cuando se aplique el cambio, correr `test-engineer → code-reviewer → security-auditor` sobre el diff (audit chain del plugin).

## Entregable

- Branch: `feature/intent-gate-per-turn`
- PR contra `main` con título: `feat(hooks): per-turn intent-gate invalidation + Bash coverage (v4.2)`
- Sin merge — el operador mergea manual (regla PR policy).

## Out of scope

- No se agrega slash command `/btw` ni equivalente.
- No se agrega allowlist/denylist de patrones Bash (todo gateado).
- No se modifica `delegation-guard.sh` (kill-switch paths inalterados).
- No se cambia el comportamiento de subagents.
- No se actualiza el CHANGELOG (puede ir en commit separado si el operador lo pide).
