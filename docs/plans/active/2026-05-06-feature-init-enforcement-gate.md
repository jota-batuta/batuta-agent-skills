# Plan: feature-init enforcement gate

## Context

`feature-init` (dentro de `batuta-project-hygiene`) es el único flujo crítico del plugin sin el patrón marker+hook que ya protege `batuta-skill-authoring` y `batuta-agent-authoring`. El modelo puede hoy crear `<feature>/CLAUDE.md` y `<feature>/SPEC.md` directamente, sin haber corrido el scaffold. Sin marker, no hay auditoría de que el flujo se completó.

Este plan implementa el gate mínimo que cierra esa brecha, replicando el patrón probado de los gates existentes.

---

## Flujo del usuario (antes vs después)

### Antes (sin enforcement)
```
Operador: "voy a implementar feature auth"
  → Modelo puede crear src/auth/CLAUDE.md directamente — gate no existe
  → SPEC.md puede no existir antes del código
  → No queda evidencia de que feature-init corrió
```

### Después (con enforcement)
```
Operador: "voy a implementar feature auth"
  → Modelo invoca batuta-project-hygiene mode=feature-init auth
  → Skill crea: branch feature/auth, src/auth/CLAUDE.md, src/auth/SPEC.md (vía spec-driven-development)
  → Skill ejecuta Step 5.5: touch .claude/.authoring-marker-feature-<ISO>
  → Modelo puede proceder a implementar código

Si el modelo intenta crear src/auth/CLAUDE.md SIN haber corrido feature-init:
  → pre-write-feature-gate.sh dispara (PreToolUse)
  → exit 1 + mensaje "RULE violated: invoke batuta-project-hygiene mode=feature-init first"
  → Modelo debe correr el skill y reintentar

Operador puede bypass: BATUTA_FEATURE_INIT_BYPASS=1 claude
```

---

## Archivos a modificar

| Archivo | Acción |
|---|---|
| `hooks/pre-write-feature-gate.sh` | **Crear** — nuevo gate |
| `hooks/hooks.json` | **Modificar** — registrar gate en PreToolUse |
| `.claude/settings.json` | **Modificar** — permiso preaprobado para touch marker-feature |
| `skills/batuta-project-hygiene/SKILL.md` | **Modificar** — insertar Step 5.5 (marker write) y actualizar Verification + Red Flags |

**Referencia para copiar estructura**: `hooks/pre-write-skill-gate.sh`

---

## Implementación

### 1. `hooks/pre-write-feature-gate.sh` (nuevo)

Lógica (misma estructura que pre-write-skill-gate.sh):

```
input ← stdin JSON (Claude Code PreToolUse protocol)
file_path ← input.tool_input.file_path

# Scope: solo **/CLAUDE.md
if file_path no termina en /CLAUDE.md → exit 0

# Excluir project root
if dirname(file_path) == "." o file_path == "CLAUDE.md" o "./CLAUDE.md" → exit 0

# Edit vs create: si el archivo ya existe → exit 0

# Resolver project_root: CLAUDE_PROJECT_DIR → git rev-parse --show-toplevel → walk-up .git/

# Bypass operador
if BATUTA_FEATURE_INIT_BYPASS=1 → log warning → exit 0

# Buscar marker fresco
marker = find project_root/.claude -name '.authoring-marker-feature-*' -mmin -60

if marker existe → exit 0

# Bloquear con mensaje
stderr: "RULE violated (feature-init gate): cannot create feature CLAUDE.md at: $file_path
No fresh marker at project_root/.claude/.authoring-marker-feature-* (expire 60 min).
Invoke: /skill batuta-project-hygiene (mode=feature-init <name>)
Step 5.5 writes the marker. Then re-attempt."
exit 1
```

Diferencias clave respecto a skill-gate:
- Usa `project_root` (via `CLAUDE_PROJECT_DIR` / git), NO `CLAUDE_PLUGIN_ROOT` — el gate aplica a consumer projects
- Sin origin check — cross-project por diseño
- Fail-soft en todos los casos de error (jq ausente → exit 0 con warn)

### 2. `hooks/hooks.json`

Agregar al array del matcher `Write|Edit|MultiEdit|NotebookEdit`, después del entry de `pre-write-agent-gate.sh`:

```json
{
  "type": "command",
  "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/pre-write-feature-gate.sh",
  "timeout": 5
}
```

### 3. `.claude/settings.json`

Agregar en `permissions.allow` después del permiso de agent marker:

```json
"Bash(touch \".claude/.authoring-marker-feature-$\\(date -u +%Y-%m-%dT%H-%M-%SZ\\)\")"
```

### 4. `skills/batuta-project-hygiene/SKILL.md`

**Step 5.5** (insertar después del bloque bash del Step 5 commit, antes de "6. Verification"):

```markdown
5.5. **Write the authoring marker (MANDATORY)**:

   After the Step 5 commit succeeds, run:

   ```bash
   mkdir -p "$(git rev-parse --show-toplevel)/.claude" && \
     touch "$(git rev-parse --show-toplevel)/.claude/.authoring-marker-feature-$(date -u +%Y-%m-%dT%H-%M-%SZ)"
   ```

   This marker is consumed by `pre-write-feature-gate.sh`. Without it, any attempt to
   create a feature CLAUDE.md in a subdirectory will be blocked at the hook. Valid 60 min.
   Gitignored (`.claude/.authoring-marker-*` already in `.gitignore`).
```

**Red Flags** — agregar bullet:
```
- Skipping Step 5.5: omitting the marker write after the scaffold commit blocks all subsequent feature CLAUDE.md creation in the session.
```

**Verification (feature-init)** — agregar al bloque bash:
```bash
find .claude -maxdepth 1 -name '.authoring-marker-feature-*' -mmin -60 | grep -q . && echo "marker OK" || echo "WARN: marker missing or expired"
```

---

## Out of scope (diferido)

- **`pre-write-spec-gate.sh`** — bloquea código sin SPEC.md. Alta complejidad, riesgo de falsos positivos. Retomar si se observa el patrón en producción.
- **Detección de keywords en `clear-intent-marker.sh`** — el canal correcto para el trigger sigue siendo el SKILL.md + using-agent-skills. Grep en bash introduciría frágil regex bilingüe que dispara en cada turno.
- **Rule file `rules/authoring/feature-init-required.md`** — se puede crear en un follow-up con evidencia de N≥2 proyectos (admission gate §A.6).
- **Propagación del permiso a consumer projects** — el `settings.json` modificado aplica al plugin repo. En proyectos cliente, el operador agrega el permiso la primera vez que lo necesite.

---

## Verificación manual

```bash
# Test 1: gate bloquea sin marker
echo '{"tool_name":"Write","tool_input":{"file_path":"features/auth/CLAUDE.md","content":"x"}}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" bash hooks/pre-write-feature-gate.sh
# Expected: exit 1, mensaje RULE violated

# Test 2: root CLAUDE.md pasa sin marker
echo '{"tool_name":"Write","tool_input":{"file_path":"CLAUDE.md","content":"x"}}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" bash hooks/pre-write-feature-gate.sh
# Expected: exit 0

# Test 3: pasa con marker fresco
mkdir -p .claude && touch ".claude/.authoring-marker-feature-$(date -u +%Y-%m-%dT%H-%M-%SZ)"
echo '{"tool_name":"Write","tool_input":{"file_path":"features/auth/CLAUDE.md","content":"x"}}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" bash hooks/pre-write-feature-gate.sh
# Expected: exit 0

# Test 4: edit (archivo existe) pasa sin marker
mkdir -p features/auth && echo "x" > features/auth/CLAUDE.md
echo '{"tool_name":"Write","tool_input":{"file_path":"features/auth/CLAUDE.md","content":"y"}}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" bash hooks/pre-write-feature-gate.sh
# Expected: exit 0

# Test 5: JSON válido después del cambio a hooks.json
jq . hooks/hooks.json > /dev/null && echo "JSON valid"
```
