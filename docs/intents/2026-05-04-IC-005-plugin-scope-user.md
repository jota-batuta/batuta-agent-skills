---
id: IC-005
status: confirmed
captured_at: 2026-05-04
confirmed_at: 2026-05-04
operator_id: jota-batuta
agent_version: claude-opus-4-7
category: bug
related_pr: TBD
related_branch: chore/plugin-scope-user-IC-005
related_plan: ""
---

# IC-005 — Move plugin from project-scope to user-scope

## Original ask

> "Investiga más por que veo que aunque teniamos claude.md claro al no estar en el proyecto el main agent tomó la ruta que se le dio la gana."

Followed by clarification:

> "Está en ese proyecto por que debí forzarlo para empezar a trabajar, por que no funcionaba."

## Diagnosis

The plugin `batuta-agent-skills@batuta-agent-skills` ended up installed with `scope: "project"` bound to `/mnt/d/BATUTA/clients/kiosco/active/BANCOS EKGS`. This was a manual workaround the operator applied when an earlier user-scope install attempt failed to populate `enabledPlugins`.

State observed:

| File | Field | Value |
|---|---|---|
| `~/.claude/settings.json` | `enabledPlugins` | `{}` (empty) |
| `~/.claude/plugins/installed_plugins.json` | `scope` | `"project"` |
| `~/.claude/plugins/installed_plugins.json` | `projectPath` | `/mnt/d/BATUTA/clients/kiosco/active/BANCOS EKGS` |
| `BANCOS EKGS/.claude/settings.json` | `enabledPlugins` | `{"batuta-agent-skills@batuta-agent-skills": true}` |

Consequence: the plugin (and therefore its hooks — including `clear-intent-marker.sh` for v4.3 auto-injection and `pre-edit-intent-gate.sh` for the reactive gate) only loads in sessions started inside BANCOS EKGS. In any other project, the plugin is inactive — hooks do not fire, MUST rules from CLAUDE.md become text without runtime enforcement, and the agent acts on its own discretion.

This explains the operator's observation that the agent "tomó la ruta que se le dió la gana" outside the project: with no hooks, the gate is not enforced. The global CLAUDE.md still loads (per [memory.md](https://code.claude.com/docs/en/memory.md): walking up the directory tree), but `CLAUDE.md` is documented as "context, not enforced configuration" — agent compliance is best-effort.

## Refined intent

Move the plugin from project-scope (BANCOS EKGS) to user-scope so its hooks fire in every Claude Code session, regardless of cwd. Three JSON files need surgical edits, with backups for reversibility.

## Scope

### In
- Edit `~/.claude/settings.json`: add `"batuta-agent-skills@batuta-agent-skills": true` to `enabledPlugins`.
- Edit `~/.claude/plugins/installed_plugins.json`: change `scope: "project"` → `"user"`, remove `projectPath`.
- Edit `BANCOS EKGS/.claude/settings.json`: remove `"batuta-agent-skills@batuta-agent-skills"` from `enabledPlugins` (set to `{}`).
- Backups of all three under `~/.claude/backups/*.pre-IC-005-<TS>` for reversibility.
- Persist this IC-005 record in plugin repo `docs/intents/`.

### Out
- No CLI uninstall+reinstall. We tried; defaults do not reliably populate user-scope `enabledPlugins` from non-project cwds (was the original failure mode).
- No edit to `known_marketplaces.json` or `extraKnownMarketplaces` — the marketplace registration is fine.
- No reset of the cache directory (`~/.claude/plugins/cache/...`).
- No changes to plugin source files in the repo.
- Operator does `/reload-plugins` (or restart) post-edit; no agent-side reload triggered.

## Acceptance

- `~/.claude/settings.json` has `enabledPlugins: {"batuta-agent-skills@batuta-agent-skills": true}`.
- `~/.claude/plugins/installed_plugins.json` plugin entry has `scope: "user"` and no `projectPath`.
- `BANCOS EKGS/.claude/settings.json` has `enabledPlugins: {}`.
- All three files parse as valid JSON.
- Three backups under `~/.claude/backups/`.
- IC-005 record persisted at `<plugin>/docs/intents/2026-05-04-IC-005-plugin-scope-user.md`.
- Operator runs `/reload-plugins` (or restarts) and verifies hooks fire in non-BANCOS-EKGS sessions.

## Routing declaration

| Trabajo | Quién | Por qué |
|---|---|---|
| Backup of three JSON files | Subagent (`implementer`) | Bash on `.claude/settings*.json` paths is gated; subagent bypasses via `agent_id` |
| Edit `~/.claude/settings.json` | Subagent | Kill-switch path (`.claude/settings.json`) — `delegation-guard.sh` blocks main |
| Edit `~/.claude/plugins/installed_plugins.json` | Subagent | Same |
| Edit `BANCOS EKGS/.claude/settings.json` | Subagent | Same |
| IC-005 record (`docs/intents/`) | Main-direct | `docs/**` exempt |
| Diagnosis + analysis | Main (Opus) | Editorial / orchestration |

## Outcome

(To be filled after operator runs `/reload-plugins` and confirms hooks fire across sessions.)

## Original JSON

```json
{
  "asks": [{
    "id": "IC-005",
    "original_text": "investiga mas por que veo que aunque teniamos claude.md claro al no estar en el proyecto el main agent tomó la ruta que se le dio la gana",
    "refined_text": "Mover plugin de project-scope (BANCOS EKGS) a user-scope vía edits surgicales a 3 archivos JSON. Backups antes. Plugin debe quedar enabled en todo cwd.",
    "scope": {
      "in": [
        "~/.claude/settings.json — agregar plugin a enabledPlugins",
        "~/.claude/plugins/installed_plugins.json — scope project→user, eliminar projectPath",
        "BANCOS EKGS/.claude/settings.json — vaciar enabledPlugins",
        "Backups bajo ~/.claude/backups/",
        "IC-005 record en docs/intents/"
      ],
      "out": [
        "No CLI uninstall+reinstall (falló antes)",
        "No edit a known_marketplaces.json",
        "No reset del cache",
        "No cambios al código del plugin"
      ]
    },
    "acceptance": [
      "Los 3 JSONs parseables",
      "scope=user en installed_plugins.json sin projectPath",
      "enabledPlugins poblado a nivel user, vacío a nivel BANCOS EKGS",
      "Backups existen",
      "IC-005 record persistido"
    ],
    "category": "bug",
    "priority": "high"
  }],
  "metadata": {
    "operator_id": "jota-batuta",
    "agent_version": "claude-opus-4-7"
  },
  "status": "confirmed"
}
```
