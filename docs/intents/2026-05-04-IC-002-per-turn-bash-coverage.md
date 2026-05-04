---
id: IC-002
status: confirmed
captured_at: 2026-05-04
confirmed_at: 2026-05-04
operator_id: jota-batuta
agent_version: claude-opus-4-7
category: feature
related_pr: 52
related_branch: feature/intent-gate-per-turn
related_plan: docs/plans/active/2026-05-04-intent-gate-per-turn.md
---

# IC-002 — Per-turn invalidation + Bash coverage (v4.2)

## Original ask

> "Cada iteración mía debe pasar por grillme sin importar el tiempo, normalmente las interacciones se dan tras finalizado un proceso. Nada es trivial, para trivialidades usaré el comando btw únicamente."

(The "btw" reference was clarified during grilling — discarded as redundant; `BATUTA_INTENT_BYPASS=1` already covers genuine trivialities.)

## Refined intent

Extend the v4.1 intent-gate with two fixes:

1. **UserPromptSubmit hook** (`clear-intent-marker.sh`) deletes markers at the start of every operator turn. No time-based window — the boundary is the operator turn itself.
2. **All-Bash coverage** — `pre-edit-intent-gate.sh` now gates ALL `Bash` tool calls. No allow-list of read-only commands and no deny-list of mutating patterns. Operator stance: "nada es trivial; para trivialidades uso `BATUTA_INTENT_BYPASS=1`".

## Scope

### In
- `hooks/clear-intent-marker.sh` (new) — UserPromptSubmit hook, fail-soft
- `hooks/pre-edit-intent-gate.sh` — Bash branch added, time window removed
- `hooks/hooks.json` — register UserPromptSubmit; add Bash matcher to PreToolUse
- `skills/intent-capture/SKILL.md` — Step 1 (per-turn invariant), Step 5 (marker scope expanded)
- `rules/core/intent-capture-required.md` — Rule 3 reworded (turn-boundary), Rule 5 inverted (Bash gated)
- `CLAUDE.md` (project + global) — bump v4.2
- `.gitignore` — add `.claude/.intent-confirmed-*` (oversight from v4.1)

### Out
- No allow/deny list of Bash patterns (gate-all)
- No `/btw` slash command (rejected as conceptual confusion)
- No changes to authoring gates or `delegation-guard.sh`

## Acceptance

- UserPromptSubmit hook deletes markers at start of each operator turn
- Hook blocks any Bash without marker (no exception list)
- `BATUTA_INTENT_BYPASS=1` still works
- Subagents bypass via `agent_id`

## Routing declaration

(Backfilled — at the time of execution, routing was implicit.)

| Trabajo | Quién | Por qué |
|---|---|---|
| `hooks/clear-intent-marker.sh` (new), `hooks/pre-edit-intent-gate.sh` (modify), `hooks/hooks.json` (modify) | Subagent (`implementer`) | Kill-switch paths — `delegation-guard.sh` blocks main on `hooks/*.sh` and `hooks/*.json` |
| `skills/intent-capture/SKILL.md`, `rules/core/intent-capture-required.md`, CLAUDE.md (project + global), `.gitignore` | Main-direct | Plugin meta-work, exempt paths |

## Outcome

Merged in PR #52 (commit `93a97db`). Followed by PR #53 (commit `5cde5af`) which bumped `plugin.json` from 4.0.0 → 4.2.0 to unstick the plugin cache (the bump had been forgotten during the v4.1 and v4.2 PRs).

A subsequent investigation revealed the cache mechanism in Claude Code's `/plugin update` only refetches when the version field changes, so version bumps must accompany every shippable change to the plugin.

Surfaced gap that drove IC-003:

1. Auto-injection — without a forced trigger, the agent's discipline is still the failure point. The reactive block from `pre-edit-intent-gate.sh` only fires AFTER the agent attempts a tool call; if the agent reasons in pure text and skips tools entirely, the gate never enforces.
2. Routing declaration — the agent's routing decision (subagent vs main-direct) was still discretionary.
3. Intent persistence — the JSON only lived in chat history; lost on compaction.

## Original JSON

```json
{
  "asks": [{
    "id": "IC-002",
    "original_text": "cada iteración mi debe pasar por grillme sin importar el tiempo",
    "refined_text": "Extender intent gate a Bash + endurecer ventana del marker: gatear todo Bash, eliminar -mmin -60, borrar markers viejos al inicio de cada turno via UserPromptSubmit, reforzar SKILL.md Step 4",
    "scope": {
      "in": [
        "hooks/pre-edit-intent-gate.sh — agregar rama Bash",
        "hooks/hooks.json — registrar UserPromptSubmit + Bash matcher",
        "hooks/clear-intent-marker.sh — nuevo, borra markers en cada turno",
        "skills/intent-capture/SKILL.md — Step 1 per-turn invariant",
        "rules/core/intent-capture-required.md — reglas 3 y 5"
      ],
      "out": [
        "No marker consumible",
        "No allowlist/denylist de Bash",
        "No /btw"
      ]
    },
    "acceptance": [
      "Hook bloquea cualquier Bash sin marker fresco",
      "Marker invalidado al inicio de cada turno (no time window)",
      "Subagentes siguen bypaseando",
      "BATUTA_INTENT_BYPASS=1 sigue como override"
    ],
    "category": "feature",
    "priority": "high"
  }],
  "metadata": {
    "operator_id": "jota-batuta",
    "agent_version": "claude-opus-4-7"
  },
  "status": "confirmed"
}
```
