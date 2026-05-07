# Plan: Audit Gap Closure + Hook-Enforced Commands

## Context

El audit integral del plugin (`feat/IC-016-flow-fix`) reveló tres tipos de brechas:

1. **Comandos que existen pero no se ejecutan automáticamente** — `/env-check`, `/vault-health`, `/pr-prep` son responsabilidades manuales del operador. Pueden y deben correr via hook.
2. **Skills que tienen lógica incompleta** — `batuta-status` no ve PRs ni intents uncommitted; `kb-end-session` no valida si la sesión produjo commits; `code-review-and-quality` no distingue quick vs thorough review.
3. **Flujos de trabajo sin comando formal** — "slices" están documentadas pero no tienen `/slice-open` + `/slice-close` que materialicen el ciclo.

IC-016 (en progreso en la rama actual) cierra el gap de seguridad del marker two-phase. Este plan asume que IC-016 mergeó antes de iniciar; no dupliques su trabajo.

## Out of scope

- Cambios a `skills/_vendored/` (upstream, no se toca)
- Modificación de la lógica de `clear-intent-marker.sh` (IC-016 ya la refactorizó)
- Nueva funcionalidad en `delegation-guard.sh` (IC-016 ya añadió la blocklist para confirmed markers)
- E2E tests (suite manual, separada de este slice)

---

## Track A — Nuevos hooks (enforcement automático)

### A-1: `hooks/hooks-health.sh` → evento `SessionStart`

**Por qué SessionStart:** Los health checks pertenecen al inicio de sesión, antes de cualquier trabajo. Si un script de hook tiene permisos incorrectos o hooks.json está corrupto, el operador lo sabe al arrancar, no cuando un gate bloquea mid-sesión y no hay diagnóstico. `session-start.sh` ya usa este evento — `hooks-health.sh` se agrega a la cadena.

**Por qué no bloqueante (exit 0 siempre):** Una condición de salud degradada (ej: jq ausente) no debe bloquear la sesión — el operador puede corregirlo. El valor está en la visibilidad, no en el bloqueo.

**Qué valida:**
- Todos los scripts en `hooks/` listados en `hooks.json` existen en disco y tienen `+x`
- `hooks.json` es JSON válido (`python3 -m json.tool` como fallback si jq ausente)
- No hay markers `.intent-pending-*` stale de sesiones previas (edad > 120 min → warning)
- `jq` disponible (warn si solo hay fallback python3)

**Timeout:** 5s. Checks son file-system only.

**Actualización hooks.json:**
```json
{
  "event": "SessionStart",
  "hooks": [
    { "type": "command", "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/hooks-health.sh", "timeout": 5000 },
    { "type": "command", "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/session-start.sh", "timeout": 15000 }
  ]
}
```
hooks-health debe correr ANTES de session-start para que sus warnings aparezcan primero.

---

### A-2: `hooks/pre-pr-create-guard.sh` → evento `PreToolUse` matcher `Bash`

**Por qué PreToolUse(Bash):** `gh pr create` es un comando Bash. PreToolUse da la oportunidad de bloquear ANTES de que el PR exista. Una vez creado, el PR es visible a otros — es un artefacto externo. Mejor bloquear que crear un PR con trabajo incompleto.

**Por qué bloqueante (exit 1 si falla):** Un PR abierto sin intents bundleados o sin plan es un slice incompleto. La fricción del bloqueo es baja (30 segundos corregir) vs el costo de un PR mal formado (reviewer confundido, re-trabajo).

**Qué valida:**
- Regex match: `gh[[:space:]]+pr[[:space:]]+create` en el comando Bash
- `docs/intents/` no tiene archivos sin commitear (`git diff --name-only HEAD -- docs/intents/` retorna vacío)
- Existe al menos un archivo en `docs/plans/active/` (no PR sin plan)
- No hay `.intent-pending-*` marker stale activo (indica intent no confirmado)

**Bypass:** `BATUTA_ALLOW_PR_CREATE=1` (mismo patrón que `pr-merge-guard.sh`). Logea warning a `.claude/kb-debug.log`.

**Posición en la cadena:** Después de `pr-merge-guard.sh`, antes de `pre-edit-intent-gate.sh`.

**Timeout:** 10s. Requiere git commands.

---

### A-3: `hooks/post-edit-citation-warn.sh` → evento `PostToolUse` matchers `Write|Edit`

**Por qué PostToolUse(Write|Edit):** La única forma de verificar que una cita `// Source:` existe es DESPUÉS de escribir el archivo. PreToolUse no tiene acceso al contenido que se va a escribir en todos los casos. El check es informacional — si encontramos un import sin cita, el modelo recibe un warning en contexto para la próxima acción.

**Por qué no bloqueante (exit 0 siempre):** `research-first-dev` dice "before writing code" — el lookup debe ocurrir antes, no puede bloquearse después. El hook cierra el loop: si el modelo escribió import sin cita, el warning activa re-verificación. Es un safety net, no una gate adicional.

**Qué detecta:** Lee `tool_input.file_path` + `tool_input.content` del stdin JSON. Si el archivo es `.py`, `.ts`, `.js`, `.tsx`, `.jsx`, `.mjs`:
- Extrae líneas con `import ` o `from ... import`
- Para cada import statement, verifica que en las 3 líneas previas exista `# Source:` o `// Source:`
- Si encuentra import sin cita → emite warning via stderr (aparece como contexto al modelo)

**No aplica a:** archivos en `tests/`, `_vendored/`, `__tests__/`, líneas que importan stdlib Python (`os`, `sys`, `re`, `json`, `pathlib`, etc.) o stdlib Node (`fs`, `path`, `url`, `crypto`, `http`).

**Timeout:** 5s. Solo lectura de stdin JSON + grep simple.

**Actualización hooks.json:**
```json
{
  "event": "PostToolUse",
  "matchers": ["Write", "Edit"],
  "hooks": [
    { "type": "command", "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/post-edit-citation-warn.sh", "timeout": 5000 }
  ]
}
```

---

## Track B — Mejoras a skills existentes

Estas son edits a archivos que ya existen — no requieren authoring gate.

### B-1: `skills/batuta-status/SKILL.md`
Añadir al Step 2 (consultas que el skill ejecuta):
- `gh pr list --state open --author @me` — lista PRs del operador abiertos
- `git diff --name-only HEAD -- docs/intents/` — detecta intents uncommitted (debería ser vacío en slice sano)
- Si `docs/plans/active/` tiene más de un plan → warning "multiple active plans, likely stale"

### B-2: `skills/kb-end-session/SKILL.md`
Añadir Step 0 — precondition check antes de ejecutar:
- Si `git log --oneline -1 --since="session start"` retorna vacío → emitir "No commits found this session. End session without journal? (y/n)" (la regla actual dice NOT if no commits pero no lo valida)
- Si `.intent-pending-*` existe → warning "Intent pending not confirmed — resolve before closing session"

### B-3: `skills/code-review-and-quality/SKILL.md`
Añadir header: **Mode** (Quick / Thorough):
- **Quick** (pre-commit): dimensiones 1+2+3 (correctness, readability, security) — skip performance y architecture deep-dive
- **Thorough** (pre-merge): las 5 dimensiones completas
El Step 0 del skill debe detectar el contexto y elegir mode automáticamente: si diff < 50 LOC → Quick; si PR description presente → Thorough.

### B-4: `skills/code-graph/SKILL.md`
Añadir al tope del Overview una caja roja:
```
> ⛔ DEPRECATED v4.1 — This skill is no longer active.
> Use `codebase-flow-mapper` for Mermaid diagrams.
> Use grep + Read for call-site queries.
```
Eliminar del frontmatter el campo `description` que lo hace aparecer como activo. Mantener el archivo para referencia histórica (git preserve).

### B-5: `skills/research-first-dev/SKILL.md`
Añadir en el Step 2 (verification): nota que `post-edit-citation-warn.sh` (hook nuevo, Track A-3) audita automáticamente cada Write/Edit y emite warning si falta cita. El hook es el safety net; el skill sigue siendo el procedimiento proactivo.

---

## Track C — Nuevos skills

Todos requieren que `batuta-skill-authoring` corra primero (gate de creación). Secuencia obligatoria per-skill: `/batuta-skill-authoring` → marker → Write SKILL.md.

### C-1: `skills/hooks-diagnose/SKILL.md`
Versión manual/detallada de `hooks-health.sh`. Para cuando el operador quiere un reporte completo, no solo warnings al inicio de sesión. Output:
- Tabla: hook / script / permisos / evento / timeout / estado (OK/WARN/BROKEN)
- Lista de markers activos en `.claude/`
- Verificación que las versiones de scripts en disco coinciden con las registradas en `hooks.json`
- Recomendación si algo está roto

### C-2: `skills/slice-open/SKILL.md` + `skills/slice-close/SKILL.md`
Dos skills que formalizan el ciclo que ya existe documentado en `CLAUDE.md`:

**`/slice-open <name>`:**
1. `git checkout -b feat/<name>`
2. `batuta-project-hygiene mode=feature-init <name>` → crea `docs/features/<name>/`
3. Crea `docs/plans/active/<YYYY-MM-DD>-<name>.md` con el template canónico
4. Primer commit: "chore: open slice <name>"

**`/slice-close`:**
1. Verifica `docs/intents/` no tiene uncommitted files
2. Verifica audit chain corrió (`test-engineer` → `code-reviewer` → `security-auditor`)
3. Mueve `docs/plans/active/<plan>.md` → `docs/plans/archive/<plan>.md`
4. Commit de cierre bundleado
5. Abre PR via `gh pr create` (si `pre-pr-create-guard.sh` pasa)
6. `/kb-end-session`

### C-3: `skills/vault-health/SKILL.md`
Check manual de salud del vault Obsidian:
- Conectividad: vault_root existe y es legible
- Wikilinks: detecta archivos `.md` sin `[[` (viola wikilink invariant)
- `related:` frontmatter: detecta archivos sin campo `related:`
- Inbox stale: `<vault>/_inbox/` con archivos > 7 días
- Deadlinks: `[[wikilinks]]` que no resuelven a ningún archivo del vault

### C-4: `skills/rules-import/SKILL.md`
Wrappea `tools/setup-rules.sh` con UX guiada:
1. Detecta proyecto (git root)
2. Lista reglas disponibles en `rules/` del plugin
3. Operador elige qué reglas importar (interactivo o `--all`)
4. Ejecuta `bash tools/setup-rules.sh` con los args correctos
5. Verifica symlinks creados
6. Añade `.claude/rules/` a `.gitignore` si no está

### C-5: `skills/pr-prep/SKILL.md`
Checklist pre-PR ejecutable (la versión manual del hook A-2):
- [ ] Audit chain corrió: `test-engineer` → `code-reviewer` → `security-auditor`
- [ ] `docs/intents/` vacío (intents bundleados en commits)
- [ ] Plan movido a `docs/plans/archive/` (o `slice-close` lo hace)
- [ ] `// Source:` presentes en todos los imports nuevos
- [ ] No secrets staged (`git diff --cached | grep -E "(API_KEY|PASSWORD|SECRET)"`)
- [ ] Branch up-to-date con main (`git log --oneline origin/main..HEAD`)

---

## Archivos a crear o modificar

| Acción | Path |
|--------|------|
| **Create** | `hooks/hooks-health.sh` |
| **Create** | `hooks/pre-pr-create-guard.sh` |
| **Create** | `hooks/post-edit-citation-warn.sh` |
| **Modify** | `hooks/hooks.json` (3 nuevas entradas) |
| **Modify** | `skills/batuta-status/SKILL.md` |
| **Modify** | `skills/kb-end-session/SKILL.md` |
| **Modify** | `skills/code-review-and-quality/SKILL.md` |
| **Modify** | `skills/code-graph/SKILL.md` |
| **Modify** | `skills/research-first-dev/SKILL.md` |
| **Create** | `skills/hooks-diagnose/SKILL.md` (requiere gate) |
| **Create** | `skills/slice-open/SKILL.md` (requiere gate) |
| **Create** | `skills/slice-close/SKILL.md` (requiere gate) |
| **Create** | `skills/vault-health/SKILL.md` (requiere gate) |
| **Create** | `skills/rules-import/SKILL.md` (requiere gate) |
| **Create** | `skills/pr-prep/SKILL.md` (requiere gate) |
| **Create** | `docs/adr/0016-audit-gap-closure.md` |
| **Create** | `tests/hook-additions/` (suite para los 3 nuevos hooks) |

---

## Secuencia de implementación

```
1. Track A (hooks) — no requieren gates
   1a. hooks-health.sh
   1b. pre-pr-create-guard.sh
   1c. post-edit-citation-warn.sh
   1d. hooks.json update

2. Track B (skill edits) — no requieren gates (edits a archivos existentes)
   2a. batuta-status, kb-end-session, code-review-and-quality, code-graph, research-first-dev

3. Track C (nuevos skills) — requieren gate por skill
   Por cada skill: /batuta-skill-authoring → marker (60min) → Write SKILL.md

4. ADR + tests
   4a. docs/adr/0016-audit-gap-closure.md
   4b. tests/hook-additions/ (authoring-gate pattern)
```

---

## Verificación

**Hooks (Track A):**
```bash
# A-1: hooks-health
bash tests/hook-additions/test-hooks-health.sh   # exit 0 expected

# A-2: pr-create-guard
# Setup: sin intents uncommitted → espera exit 0
# Setup: con docs/intents/test.md sin commitear → espera exit 1
bash tests/hook-additions/test-pr-create-guard.sh

# A-3: citation-warn
# Setup: write a .py file con import requests sin # Source: → espera stderr warning
bash tests/hook-additions/test-citation-warn.sh
```

**Session start (A-1 integrado):**
```bash
# Simula SessionStart con plugin root válido
echo '{}' | CLAUDE_PLUGIN_ROOT=/mnt/d/BATUTA/platform/active/batuta-agent-skills \
  bash hooks/hooks-health.sh
# Espera: exit 0 + output JSON con campo "warnings": []
```

**Skill edits (Track B):**
```bash
bash tests/v2.5-validators/run.sh   # static contract still passes
# Verifica que skill YAML frontmatter aún válido:
python3 -c "
import yaml, pathlib
for p in pathlib.Path('skills').rglob('SKILL.md'):
    fm = p.read_text().split('---')[1]
    yaml.safe_load(fm)
print('All SKILL.md frontmatter valid')
"
```

**Nuevos skills (Track C):**
Cada SKILL.md nuevo: frontmatter con `name` y `description`, secciones Overview / When to Use / Process / Red Flags / Verification presente. El script de validators existente lo verifica (`tests/v2.5-validators/run.sh`).

---

## Open questions

1. **`/slice-open` + `/slice-close` como un skill o dos?** Dos skills separados es más limpio para el trigger en `using-agent-skills`; un skill con sub-commands es más simple de mantener. Mi preferencia: dos skills.

2. **`post-edit-citation-warn.sh` — ¿también cubre `Bash`?** Si el modelo ejecuta `curl > file.py` via Bash, el hook PostToolUse(Write) no lo ve. ¿Vale añadir PostToolUse(Bash) con grep en el output? Scope ampliable, pero complica el primer corte.

3. **Branch strategy:** ¿Este slice va en `feat/audit-gap-closure` separada de IC-016, o espera al merge de IC-016 y sale de main directamente? Mi recomendación: nueva rama desde main post-merge de IC-016.
