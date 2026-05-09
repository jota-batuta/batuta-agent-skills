# Plan de Ajuste Completo — batuta-agent-skills

## Contexto

El análisis skill-por-skill, hook-por-hook, regla-por-regla y agente-por-agente revela un patrón consistente: **los artefactos que HACEN algo (gates, automatización, routing de costo, KB) justifican su existencia; los artefactos que EXPLICAN algo que Claude ya sabe son peso muerto.**

Claude Code ya trae en su system prompt: lectura antes de editar, commits atómicos, no force-push, no agregar features innecesarias, no comentarios por defecto, TDD, seguridad OWASP. Repetir esas instrucciones en skills de 200-400 líneas no refuerza el comportamiento — solo consume tokens y agrega latencia.

### Decisiones del operador (resueltas)

1. **Intent protocol → Opción B** (simplificar pero mantener markers lite)
2. **`.aider.conf.yml` → PRESERVAR** (es una guía/template para Aider config)
3. **codebase-memory-mcp → ELIMINAR** (code-graph tools borrados)
4. **`source-driven-development` → PRESERVAR** (decisión previa del operador, workflow AI-first)

### Números actuales → objetivo

| Categoría | Antes | Después | Líneas antes | Líneas después |
|---|---|---|---|---|
| Skills | 31 | 24 | ~9,000 | ~2,800 |
| Hooks | 15 | 12 | ~2,200 | ~1,800 |
| Rules | 11 | 10 | ~1,500 | ~900 |
| Agents | 9 | 9 | ~1,200 | ~700 |
| References | 7 | 2 | ~1,340 | ~200 |
| Tools | 6 | 4 | ~800 | ~350 |
| **Total** | **81** | **62** | **~16,100** | **~6,800** |

**Reducción neta: ~9,300 líneas (58%), 19 artefactos eliminados.**

---

## Fase 0 — Decisiones (RESUELTAS)

**Intent protocol → Opción B (preservar lite):**
- `intent-capture` se SIMPLIFICA a ~30 líneas (tiering + "ask before acting on standard tier")
- `pre-edit-intent-gate.sh` se MANTIENE con markers (simplificado, sin JSON schema ni docs/intents/)
- `clear-intent-marker.sh` se ELIMINA (overhead en cada UserPromptSubmit)
- `pre-task-routing-gate.sh` se ELIMINA (redundante con permisos de Claude Code)
- `intent-capture-required.md` se SIMPLIFICA a ~30 líneas (sin marker lifecycle detallado)

**`source-driven-development` → PRESERVAR** como skill standalone (workflow AI-first del operador). Se simplifica a ~30 líneas (tabla de prioridad de fuentes + redirect a research-first-dev).

**`.aider.conf.yml` → PRESERVAR** (guía/template).

**codebase-memory-mcp → ELIMINAR** (tools/setup-code-graph.sh + tools/check-code-graph-engines.sh).

---

## Fase 1 — Eliminar Skills (−7 skills, −2,588 líneas)

Eliminar completamente — su contenido es nativo de Claude Code o del system prompt.

| # | Skill | Líneas | Motivo |
|---|---|---|---|
| 1 | `using-agent-skills` | 76 | Router circular — existe para routear a skills que no necesitan existir |
| 2 | `context-engineering` | 63 | Reafirma "lee antes de escribir" — ya en system prompt de Edit tool |
| 3 | `git-workflow-and-versioning` | 301 | System prompt ya cubre commits atómicos, no force-push, mensajes imperativos |
| 4 | `quality-axes` | 1,246 | OWASP, N+1, Core Web Vitals, Chesterton's Fence — todo en training data de Claude |
| 5 | `ci-cd-and-automation` | 391 | GitHub Actions docs reescritos peor |
| 6 | `shipping-and-launch` | 310 | Checklist DevOps genérica que Claude regenera en 10 segundos |
| 7 | `spec-driven-development` | 201 | Claude Code tiene plan mode nativo |

**No se eliminan:** `intent-capture` (Opción B → se simplifica a 30 líneas), `source-driven-development` (decisión del operador → se simplifica a 30 líneas).

### Acciones

```bash
rm -rf skills/using-agent-skills/
rm -rf skills/context-engineering/
rm -rf skills/git-workflow-and-versioning/
rm -rf skills/quality-axes/
rm -rf skills/ci-cd-and-automation/
rm -rf skills/shipping-and-launch/
rm -rf skills/spec-driven-development/
```

---

## Fase 2 — Simplificar Skills (16 skills, ~4,700 → ~1,060 líneas)

Para cada skill: conservar SOLO lo que Claude no haría por sí solo. Eliminar tutoriales, textbook content, y secciones que repiten el training data.

**Prioridad de simplificación** (por tamaño descendente — mayor impacto primero):
1. `planning-and-task-breakdown` (416 líneas → ~40) — **primero**
2. `interface-and-ui-design` (590 → ~100)
3. `batuta-project-hygiene` (561 → ~150)
4. `ai-agent-runtime` (612 → ~150)
5. `ai-agent-foundation` (506 → ~150)
6. El resto en cualquier orden

| Skill | Antes | Después | Qué conservar | Qué eliminar |
|---|---|---|---|---|
| `intent-capture` | 151 | ~30 | Heurística de tiering (trivial: ≤3 files, ≤20 LOC, no new control flow); "ask before acting on standard tier"; marker write | JSON schema, dimensional routing table, commit bundling, docs/intents/ persistence |
| `source-driven-development` | 60 | ~30 | Tabla de prioridad de fuentes (L1-L5); redirect a research-first-dev | Texto de "compatibility wrapper" — ya no es wrapper, es workflow AI-first |
| `research-first-dev` | 153 | ~40 | Mandato 6-layer harness; formato de citación | "Busca cosas antes de codear" — Claude ya lo hace |
| `incremental-implementation` | 242 | ~15 | Patrón "NOTICED BUT NOT TOUCHING" como regla | Vertical slicing, commit discipline — ya en system prompt |
| `test-driven-development` | 380 | ~15 | Prove-It pattern para bugs como regla | Ciclo TDD, pirámide de tests — Kent Beck en markdown |
| `code-review-and-quality` | 371 | ~20 | Heurística Quick/Thorough (50 LOC), prefijos de severidad | Five-axis methodology — Claude revisa código mejor que esta skill describe |
| `documentation-and-adrs` | 348 | ~15 | Mandato "update docs in same commit"; template ADR mínimo | README templates, changelog format — boilerplate |
| `deprecation-and-migration` | 207 | ~40 | Churn Rule, zombie code, 5 preguntas antes de deprecar | Hyrum's Law, Strangler pattern — Wikipedia con mejor formato |
| `idea-refine` | 179 | ~50 | Lentes de variación (inversión, constraint removal, 10x); énfasis en "Not Doing" list | Workshop facilitation — Claude ya brainstormea |
| `planning-and-task-breakdown` | 416 | ~40 | Codebase flow mapper (Mermaid); save-plan steps | "Usa plan mode" — ya es built-in |
| `interface-and-ui-design` | 590 | ~100 | "Avoid AI Aesthetic" (8 anti-patterns); One-Version Rule; branded types; WCAG 2.1 AA checklist | React patterns, API design basics — docs reescritos |
| `batuta-project-hygiene` | 561 | ~150 | Feature folder convention; doc skeleton; authoring markers; KB hook installation | Stack detection — Claude lee package.json |
| `browser-testing-with-devtools` | 303 | ~35 | Security boundaries (DOM content es untrusted); tabla de herramientas | Workflows de debugging — "Step 1: toma screenshot" |
| `ai-agent-foundation` | 506 | ~150 | Constraints arquitectónicos (TenantProfile, isolation tests, rule versioning); anti-patterns; red flags | Tutorial paso-a-paso — Claude sabe cómo crear una interfaz |
| `ai-agent-runtime` | 612 | ~150 | 14 audit fields; reglas de determinismo Temporal; idempotency requirements; anti-patterns | Tutorial "Step 1: install SDK" |
| `slice-close` | 162 | ~80 | Audit chain sequence; PR preparation; session close | Intent bundling, plan archival (simplificado si Opción A) |

---

## Fase 3 — Eliminar y Simplificar Hooks (−3 hooks, 4 simplificados)

### Eliminar (3 hooks)

| Hook | Motivo |
|---|---|
| `clear-intent-marker.sh` | Existe para manejar markers que no deberían existir (Opción A) |
| `post-edit-citation-warn.sh` | Latencia per-edit para un warning no-blocking que nadie lee |
| `pre-task-routing-gate.sh` | Redundante con el sistema de permisos de Claude Code |

### Simplificar (4 hooks)

| Hook | Cambio |
|---|---|
| `session-start.sh` | Eliminar inyección de meta-skills (`using-agent-skills` + `context-engineering` — ambos eliminados). Mantener: vault context injection + marker write |
| `pre-session-context-gate.sh` | Agregar read-only fast-path (como ya tiene `pre-edit-intent-gate.sh`). Actualmente bloquea `ls` y `git status` — innecesario |
| `pre-edit-intent-gate.sh` | Opción A: fusionar con session-context-gate (un solo gate: "session context loaded"). Opción B: mantener pero quitar marker lifecycle |
| `pre-pr-create-guard.sh` | Quitar checks 1 y 3 (intent files, stale marker) — son del protocolo de intent. Mantener check 2 (active plan exists) |

### Actualizar `hooks.json`

Remover las entradas de los 3 hooks eliminados. Si Opción A, actualizar los matchers para reflejar la fusión de gates.

### Preservar sin cambios (8 hooks)

hooks-health.sh, post-exit-plan-mode.sh, post-commit-kb.sh, delegation-guard.sh, pr-merge-guard.sh, pre-write-skill-gate.sh, pre-write-agent-gate.sh, pre-write-feature-gate.sh

---

## Fase 4 — Eliminar y Simplificar Rules (−1 rule, 4 simplificadas)

### Eliminar (1 rule)

| Rule | Motivo |
|---|---|
| `code-style.md` | Rule 2 ("every public function has docstring") contradice system prompt de Claude Code ("default to writing no comments"). Las otras reglas (naming, 500-line limit) son comportamiento nativo |

### Simplificar (4 rules)

| Rule | Antes | Después | Qué conservar |
|---|---|---|---|
| `research-first-citations.md` | ~60 | ~10 | "Cita imports externos con `// Source: <url> (verified date, lib@version)`". Eliminar: jerarquía de búsqueda, evidence packs |
| `secrets-and-pii.md` | ~50 | ~10 | Mantener Rule 3 (fail-fast on missing secrets) y Rule 4 (secrets via env/manager). Eliminar Rules 1-2 (Claude ya lo hace) |
| `no-hardcoded-magic.md` | ~40 | ~10 | "Valores que varían por cliente/tenant/environment van en config, no inline". Eliminar Rules 2-4 (padding) |
| `intent-capture-required.md` | 188 | ~30 | Mantener tiering heuristic (trivial: ≤3 files, ≤20 LOC, no new control flow → no grill). Eliminar: marker lifecycle, JSON schema, commit bundling, dimensional routing, tool-portability matrix |

### Preservar sin cambios (6 rules)

tenant-ready-design.md, model-routing.md, session-context-gate.md, agent-authoring-required.md, feature-init-required.md, skill-authoring-required.md

---

## Fase 5 — Simplificar Agents (4 agentes, ~600 → ~80 líneas)

Los 4 agentes del audit chain tienen valor por **independencia** (instancia Sonnet separada del implementer) y **routing de costo** (Sonnet en vez de Opus). NO tienen valor como tutoriales de metodología.

| Agent | Antes | Después | Qué conservar | Qué eliminar |
|---|---|---|---|---|
| `code-reviewer.md` | ~150 | ~20 | model, tools, role ("independent five-axis reviewer"), output format (AUDIT RESULT: APPROVED/BLOCKED) | Five-axis methodology, change sizing guidance, dead code section — Claude ya sabe |
| `implementer.md` | ~150 | ~20 | model, tools, role ("spec-to-code implementer"), output format (build-log.md, READY FOR AUDIT) | Research-first instructions, implementation process — es lo que Claude hace por defecto |
| `security-auditor.md` | ~150 | ~20 | model, tools, role ("independent security reviewer, GATE 3"), output format (AUDIT RESULT) | OWASP Top 10 refresher, threat modeling process — training data de Claude |
| `test-engineer.md` | ~150 | ~20 | model, tools, role ("independent test engineer, GATE 1"), output format (AUDIT RESULT), scope restriction (tests/ only) | Test methodology, coverage analysis guidance — Claude ya sabe TDD |

### Preservar sin cambios (5 agents)

agent-architect.md, implementer-haiku.md, kb-backfiller.md, kb-curator.md, kb-pipeline.md

---

## Fase 6 — Actualizar Infraestructura

### 6.1 — `hooks/hooks.json`
- Remover entradas: `clear-intent-marker.sh`, `post-edit-citation-warn.sh`, `pre-task-routing-gate.sh`
- Actualizar matchers si se fusionan gates (Opción A)

### 6.2 — `session-start.sh`
- Eliminar las líneas que inyectan `using-agent-skills` y `context-engineering` (skills eliminados)
- Mantener: vault context injection, KB loading, session marker write

### 6.3 — `docs/SKILL_MAP.md`
- Reescribir con las 22 skills sobrevivientes
- Documentar consolidaciones en `## Merged/Deleted Skills (v5.x)`

### 6.4 — `.claude/commands/`
- Verificar que ningún command reference una skill eliminada
- `batuta-status.md` — ya actualizado

### 6.5 — `user-settings/CLAUDE.md`
- Actualizar sección "Mandatory Skills" para reflejar el inventario final
- Mover las heurísticas de tiering a esta sección (si Opción A)

---

## Estado Final

### Skills (24)

```
HOT PATH (9):
  intent-capture ............... ~30 líneas (tiering + ask before standard)
  source-driven-development .... ~30 líneas (source priority table + redirect)
  research-first-dev ........... ~40 líneas (mandato 6-layer + citaciones)
  incremental-implementation ... ~15 líneas (regla NOTICED BUT NOT TOUCHING)
  test-driven-development ...... ~15 líneas (Prove-It pattern)
  code-review-and-quality ...... ~20 líneas (Quick/Thorough + severity)
  slice-close .................. ~80 líneas (audit chain + PR + session)
  idea-refine .................. ~50 líneas (lenses + Not Doing list)
  planning-and-task-breakdown .. ~40 líneas (flow mapper + save-plan)

AUTHORING GATES (3):
  batuta-skill-authoring ....... sin cambios
  batuta-agent-authoring ....... sin cambios
  batuta-rule-authoring ........ sin cambios

AI AGENT HARNESS (2):
  ai-agent-foundation .......... ~150 líneas (constraints + anti-patterns)
  ai-agent-runtime ............. ~150 líneas (14 fields + determinism + idempotency)

KB PIPELINE (4):
  batuta-kb-vault .............. sin cambios
  kb-backfill .................. sin cambios
  kb-curate .................... sin cambios
  kb-end-session ............... sin cambios

DELIVERY + DESIGN (4):
  documentation-and-adrs ....... ~15 líneas (per-slice mandate)
  deprecation-and-migration .... ~40 líneas (Churn Rule + zombie code)
  interface-and-ui-design ...... ~100 líneas (AI aesthetic + WCAG + One-Version)
  browser-testing-with-devtools  ~35 líneas (security boundaries + tool table)

PLUGIN MAINTENANCE (2):
  batuta-project-hygiene ....... ~150 líneas (feature-init + doc skeleton)
  batuta-status ................ sin cambios
```

### Hooks (12)

```
PRESERVADOS (8):
  hooks-health.sh, post-exit-plan-mode.sh, post-commit-kb.sh,
  delegation-guard.sh, pr-merge-guard.sh,
  pre-write-skill-gate.sh, pre-write-agent-gate.sh, pre-write-feature-gate.sh

SIMPLIFICADOS (4):
  session-start.sh ............. sin meta-skill injection
  pre-session-context-gate.sh .. con read-only fast-path
  pre-edit-intent-gate.sh ...... fusionado o simplificado (según Opción)
  pre-pr-create-guard.sh ....... solo check de active plan

ELIMINADOS (3):
  clear-intent-marker.sh, post-edit-citation-warn.sh, pre-task-routing-gate.sh
```

### Rules (10)

```
PRESERVADAS (6):
  tenant-ready-design, model-routing, session-context-gate,
  agent-authoring-required, feature-init-required, skill-authoring-required

SIMPLIFICADAS (4):
  research-first-citations ..... ~10 líneas
  secrets-and-pii .............. ~10 líneas
  no-hardcoded-magic ........... ~10 líneas
  intent-capture-required ...... ~30 líneas

ELIMINADA (1):
  code-style (contradice system prompt)
```

### Agents (9)

```
PRESERVADOS (5):
  agent-architect, implementer-haiku, kb-backfiller, kb-curator, kb-pipeline

SIMPLIFICADOS (4):
  code-reviewer ................ ~20 líneas (role + output format)
  implementer .................. ~20 líneas (role + output format)
  security-auditor ............. ~20 líneas (role + output format)
  test-engineer ................ ~20 líneas (role + output format)
```

---

## Fase 7 — References (7 archivos, 1,341 líneas)

Los references son "long-form playbooks" y checklists vinculados a skills. Si el skill padre se elimina, el reference queda huérfano.

### Eliminar (5 references, −1,048 líneas)

| Archivo | Líneas | Motivo |
|---|---|---|
| `context-engineering-playbook.md` | 293 | Skill padre (`context-engineering`) eliminado — "load context before editing" es nativo |
| `using-agent-skills-longform.md` | 183 | Skill padre (`using-agent-skills`) eliminado — routing table circular |
| `testing-patterns.md` | 237 | AAA, mocking, Playwright, React testing — training data de Claude reformateado |
| `performance-checklist.md` | 140 | Core Web Vitals, N+1, bundle size — Claude lo sabe; skill padre (`quality-axes`) eliminado |
| `security-checklist.md` | 135 | OWASP Top 10, CSP, CORS — Claude lo sabe; skill padre (`quality-axes`) eliminado |

### Simplificar (1 reference)

| Archivo | Antes | Después | Cambio |
|---|---|---|---|
| `source-driven-development-playbook.md` | 199 | ~40 | Si `source-driven-development` se absorbe en `research-first-dev`, fusionar las 5 líneas útiles (source hierarchy table) y eliminar el playbook. Si se mantiene como skill, simplificar como su skill padre |

### Preservar (1 reference)

| Archivo | Líneas | Motivo |
|---|---|---|
| `accessibility-checklist.md` | 161 | Vinculado a `interface-and-ui-design` (preservado). WCAG 2.1 AA checklist operacional — Claude lo conoce genéricamente pero el checklist en formato ejecutable (copiar→verificar) tiene valor como reference rápido |

---

## Fase 8 — Tools (6 archivos, 801 líneas)

### Eliminar (2 tools, −456 líneas)

| Archivo | Líneas | Motivo |
|---|---|---|
| `setup-code-graph.sh` | 365 | Instala `codebase-memory-mcp` v0.6.0 — el skill `codebase-flow-mapper` fue absorbido y `code-graph` fue deprecado. Si el MCP server ya no se usa, este installer es dead code |
| `check-code-graph-engines.sh` | 92 | Status checker para el engine anterior. Huérfano si `setup-code-graph.sh` se elimina |

### Preservar (4 tools)

| Archivo | Líneas | Motivo |
|---|---|---|
| `setup-rules.sh` | 138 | Infraestructura de distribución de rules a consumer projects — necesario |
| `kb-resync.sh` | 115 | Reconcilia session journal con git log post-rebase — útil para KB system |
| `validate-plugin.sh` | 66 | CI validator para el plugin contract — necesario para releases |
| `README.md` | 31 | Documentación de tools — necesario si tools existen |

---

## Fase 9 — Prompts y .aider.conf.yml

### `prompts/prompt_log.md` (12 líneas)

**Qué es:** Log manual de decisiones de sesión con fecha, tarea, contexto y outcome.

**Veredicto: PRESERVAR** — Es un registro histórico de decisiones operacionales. No consume tokens (no se inyecta en contexto). Cero costo, valor de auditoría.

> Uno de los pocos artefactos que registra el "por qué" detrás de decisiones pasadas sin agregarse al context window.

### `.aider.conf.yml` (11 líneas)

**Qué es:** Config de Aider (pair programmer open-source) auto-generado por `batuta-project-hygiene`. Define read list (AGENTS.md, PRD, SPEC, plans) y `auto-commits: false`.

**Veredicto: PRESERVAR** si se usa Aider, **ELIMINAR** si no.

> 11 líneas de config para una herramienta que puede o no estar en uso — preguntarle al operador.

---

## Resumen total con todas las fases

| Categoría | Antes | Eliminar | Simplificar | Preservar | Después |
|---|---|---|---|---|---|
| Skills | 31 (9,000 ln) | 9 (3,000 ln) | 14 (→ 850 ln) | 8 | **22** (~2,500 ln) |
| Hooks | 15 (2,200 ln) | 3 (400 ln) | 4 | 8 | **12** (~1,800 ln) |
| Rules | 11 (1,500 ln) | 1 (40 ln) | 4 (→ 60 ln) | 6 | **10** (~900 ln) |
| Agents | 9 (1,200 ln) | 0 | 4 (→ 80 ln) | 5 | **9** (~700 ln) |
| References | 7 (1,341 ln) | 5 (1,048 ln) | 1 (→ 40 ln) | 1 | **2** (~200 ln) |
| Tools | 6 (801 ln) | 2 (456 ln) | 0 | 4 | **4** (~350 ln) |
| Prompts | 1 (12 ln) | 0 | 0 | 1 | **1** (12 ln) |
| Config | 1 (11 ln) | 0-1 | 0 | 0-1 | **0-1** |
| **Total** | **81** (~16,100 ln) | **20-21** | **27** | **33-34** | **~60** (~6,500 ln) |

**Reducción neta: ~9,600 líneas (60%), ~21 artefactos eliminados.**

---

## Orden de Ejecución

```
Fase 0  RESUELTA — todas las decisiones tomadas
Fase 1  Eliminar 7 skill directories                              (paralelo)
Fase 2  Simplificar 16 skills (rewrite in-place)                  (paralelo, empezar por planning-and-task-breakdown)
Fase 3  Eliminar 2 hooks + simplificar 3 hooks + actualizar hooks.json
Fase 4  Eliminar 1 rule + simplificar 4 rules                    (paralelo)
Fase 5  Simplificar 4 agents                                     (paralelo)
Fase 6  Actualizar infraestructura (SKILL_MAP, session-start, CLAUDE.md, commands)
Fase 7  Eliminar 5 references + simplificar 1                    (paralelo con Fase 1)
Fase 8  Eliminar 2 tools (code-graph)                            (paralelo con Fase 1)
```

---

## Verificación

```bash
# Skills
find skills/ -name "SKILL.md" | wc -l              # expect 24
find skills/ -name "SKILL.md" -exec wc -l {} + | tail -1  # expect ~2,800

# Hooks
ls hooks/*.sh | wc -l                               # expect 12
jq '.[] | length' hooks/hooks.json                   # validate JSON

# Rules
find rules/ -name "*.md" ! -path "*/_meta/*" | wc -l  # expect 10

# Agents
ls agents/*.md | wc -l                              # expect 9

# Deleted skills should not exist
for d in using-agent-skills context-engineering git-workflow-and-versioning \
         quality-axes ci-cd-and-automation shipping-and-launch \
         spec-driven-development; do
  ls "skills/$d/" 2>&1 | grep -q "No such file" && echo "OK: $d deleted" || echo "FAIL: $d exists"
done

# Deleted hooks should not be in hooks.json
for h in clear-intent-marker post-edit-citation-warn pre-task-routing-gate; do
  grep -q "$h" hooks/hooks.json && echo "FAIL: $h in hooks.json" || echo "OK: $h removed"
done

# Deleted rule should not exist
ls rules/core/code-style.md 2>&1 | grep -q "No such file" && echo "OK" || echo "FAIL"
```

---

## Principio rector

> **Si Claude ya lo sabe, no lo repitas. Si Claude no lo haría solo, escribe la RESTRICCIÓN, no el TUTORIAL.**

Los skills que sobreviven contienen: constraints arquitectónicos que Claude no inferiría (6-layer harness, 14 audit fields, TenantProfile), heurísticas operacionales no obvias (Prove-It, Quick/Thorough, AI aesthetic anti-patterns, Churn Rule), o infraestructura que ejecuta trabajo real (vault, audit chain, authoring gates).

Los skills eliminados son: el training data de Claude reformateado como markdown.
