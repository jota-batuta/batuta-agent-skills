---
id: IC-004
status: confirmed
captured_at: 2026-05-04
confirmed_at: 2026-05-04
operator_id: jota-batuta
agent_version: claude-opus-4-7
category: refactor
related_pr: TBD
related_branch: chore/global-claude-md-prune-IC-004
related_plan: ""
---

# IC-004 — Global ~/.claude/CLAUDE.md prune (behavior-only)

## Original ask

> "El claude.md del user debe ser actualizado? Ese claude.md no tiene por qué declarar versiones, debemos curarlo. Es el comportamiento del agente. Todo lo que está por fuera de ahí es basura que ocupa contexto, por eso no funciona. Con un agente Opus 4.7 verifica la estructura y haz una poda para mantener eficiente el claude.md. Dime qué cambias, qué mantienes y qué estructura tendrá de tal manera que podamos operar tranquilamente. Parte del problema discrecional es que claude.md funge como patrón de comportamiento de Claude Code, diferente al claude.md del proyecto, y diferente al claude.md del feature: cada uno tiene alcance distinto."

## Refined intent

Prune `~/.claude/CLAUDE.md` (the user-global Claude Code behavior contract) so it contains ONLY cross-project agent behavior. Remove:

- Plugin version histories (v3.8 / v4.0 / v4.1 / v4.2 / v4.3) — moving target, gets stale immediately, irrelevant to behavior.
- MUST-A/B/C/D/E section labels — internal plugin nomenclature, not behavioral concepts the agent needs to reason about.
- Detailed enforcement mechanisms (marker file paths, hook script names, exempt path lists) — these belong in `rules/*.md` and load only when needed.
- Migration notes ("Removed in v4.0", "ADR-0013 distillation", etc.) — belong in CHANGELOG/ADRs.
- Setup-rules.sh instructions — onboarding doc, not behavior. Move to plugin docs.
- Long rationale paragraphs explaining "why this gate exists" — distract from the imperative the agent should act on.

The operating principle: if the content changes with the plugin (versions, hooks, file paths, exempt lists), it does not belong in the global CLAUDE.md — it belongs in `rules/`. If it is universal behavior independent of any specific plugin version, it stays.

## Scope

### In
- Rewrite `/home/jnmz/.claude/CLAUDE.md` from ~290 lines to ~100, behavior-only.
- Backup the previous version under `/home/jnmz/.claude/backups/CLAUDE.md.pre-IC-004-<TS>` for reference.
- Persist this IC record at `<plugin>/docs/intents/2026-05-04-IC-004-global-claude-md-prune.md`.

### Out
- Project CLAUDE.md (`<plugin>/CLAUDE.md`) — separate scope, project-level.
- `rules/*.md` content — already detailed, no changes.
- The plugin's own `docs/intents/`, `docs/adr/`, etc. — unchanged.
- No deletion of historical content — it lives in the backup file and in git history of `rules/core/intent-capture-required.md`.

## Acceptance

- `~/.claude/CLAUDE.md` contains: Language, Research, Divergent thinking, Git, Authoring gates (compact), Intent capture (compact), Delegation, Project hygiene, Obsidian KB, Plugin rules, Boundaries.
- ~~10 sections~~ → 11 sections, ~100 lines vs 290 prior.
- Zero version numbers (v4.x) referenced.
- Zero "MUST-A/B/C/D/E" labels.
- Zero version-history paragraphs ("v4.1 had two gaps", "v4.2 closes both", etc.).
- Backup of old version exists.
- IC-004 record persisted in plugin repo.

## Routing declaration

| Trabajo | Quién | Por qué |
|---|---|---|
| Análisis estructural | Main (Opus 4.7) | Curación editorial, no se delega |
| Rewrite `~/.claude/CLAUDE.md` | Main-direct | Fuera del repo plugin, no es kill-switch, no requiere marker (path no .git/) |
| Backup pre-prune | Main-direct (Bash) | Idem |
| IC-004 record (`docs/intents/`) | Main-direct | `docs/**` exempt |

No subagent involvement — pure editorial work, no implementation code.

## Outcome

(To be filled on merge.)

## Original JSON

```json
{
  "asks": [{
    "id": "IC-004",
    "original_text": "ese claude.md no tiene por que declarar versiones, debemos curarlo es el comportamiento del agente",
    "refined_text": "Podar ~/.claude/CLAUDE.md para que contenga SOLO patrones de comportamiento cross-project. Eliminar version histories, rationale de implementación, detalles de mecanismo (que viven en rules/). Reducir de ~300 líneas a ~80-100. La regla operativa: si el contenido cambia con el plugin (versiones, hooks específicos), no va en el global — va en rules/. Si es comportamiento universal del agente independiente del plugin, sí va.",
    "scope": {
      "in": [
        "Rewrite ~/.claude/CLAUDE.md (~290 → ~100 lines)",
        "Backup pre-prune en ~/.claude/backups/",
        "IC-004 record persistido en plugin repo"
      ],
      "out": [
        "Project CLAUDE.md no se toca",
        "rules/*.md no cambian",
        "No se borran ADRs ni docs/intents/"
      ]
    },
    "acceptance": [
      "Cero referencias a v4.x en el global",
      "Cero MUST-A/B/C/D/E labels",
      "~100 líneas, 11 secciones de comportamiento",
      "Backup existe",
      "IC-004 record persistido"
    ],
    "category": "refactor",
    "priority": "high",
    "clarifications": [
      {"question": "Niveles de CLAUDE.md", "answer": "Global = behavior cross-project; Project = conventions del proyecto; Feature = scope feature. Cada uno tiene alcance distinto, no se duplican."}
    ]
  }],
  "metadata": {
    "operator_id": "jota-batuta",
    "agent_version": "claude-opus-4-7"
  },
  "status": "confirmed"
}
```
