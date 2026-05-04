---
id: IC-001
status: confirmed
captured_at: 2026-05-04
confirmed_at: 2026-05-04
operator_id: jota-batuta
agent_version: claude-opus-4-7
category: feature
related_pr: 51
related_branch: feature/intent-capture-enforcement
related_plan: ""
---

# IC-001 — Intent-capture runtime enforcement (v4.1)

## Original ask

> "No está funcionando en la realidad el GrillMe y hace cualquier cosa; no está validando conmigo antes de operar."

## Refined intent

Implement runtime enforcement for intent-capture using a PreToolUse hook + marker file pattern, replicating the existing skill-authoring and agent-authoring gates. The hook blocks `Edit`/`Write` on implementation paths when no fresh `.intent-confirmed` marker exists. The intent-capture skill writes the marker on operator confirmation.

## Scope

### In
- `hooks/pre-edit-intent-gate.sh` (new) — PreToolUse hook
- `hooks/hooks.json` — register hook
- `skills/intent-capture/SKILL.md` — Step 5 writes marker
- `rules/core/intent-capture-required.md` (new) — §A.4 importable rule
- `CLAUDE.md` (project) — declare MUST trigger
- `~/.claude/CLAUDE.md` (global) — Authoring gates section
- PR via `gh pr create`, no merge

### Out
- No `Bash` gating (heuristic, fragile)
- No changes to existing authoring gates or `delegation-guard.sh`

## Acceptance

- Hook blocks Edit/Write on non-exempt paths without fresh marker (60-min window initially, removed in v4.2)
- Exempt paths: `.claude/**`, `docs/**`, `**/CLAUDE.md`, `**/MEMORY.md`, `memory/**`, etc.
- `BATUTA_INTENT_BYPASS=1` works as override
- Hook registered alongside skill-gate and agent-gate
- Rule file follows §A.4 format

## Routing declaration

(Backfilled — at the time of execution, routing was implicit.)

| Trabajo | Quién | Por qué |
|---|---|---|
| `hooks/pre-edit-intent-gate.sh` (new) + `hooks/hooks.json` | Subagent (`implementer`) | Kill-switch path |
| `skills/intent-capture/SKILL.md`, `rules/core/intent-capture-required.md` (new), CLAUDE.md (project + global) | Main-direct | Plugin meta-work |

## Outcome

Merged in PR #51 (commit `3cf0cd9`). Surfaced two gaps that drove IC-002:

1. Bash not gated — `git commit`/`git push`/`gh pr create` bypassed enforcement.
2. 60-min window let multiple operator turns share one confirmation, defeating the per-ask grilling contract.

## Original JSON

(Backfilled — full JSON not preserved in chat at the time. Reconstructed from intent narrative and PR #51 description.)

```json
{
  "asks": [{
    "id": "IC-001",
    "original_text": "No está funcionando en la realidad el GrillMe y hace cualquier cosa",
    "refined_text": "Implement runtime enforcement for intent-capture using a PreToolUse hook + marker file pattern.",
    "scope": {
      "in": [
        "hooks/pre-edit-intent-gate.sh (nuevo)",
        "hooks/hooks.json (registrar hook)",
        "skills/intent-capture/SKILL.md (agregar escritura de marker en Step 5)",
        "rules/core/intent-capture-required.md (nuevo)",
        "CLAUDE.md proyecto y global"
      ],
      "out": [
        "No se gatean comandos Bash",
        "No se modifican los authoring gates existentes"
      ]
    },
    "acceptance": [
      "Hook bloquea Edit/Write en paths no-exentos sin marker reciente",
      "BATUTA_INTENT_BYPASS=1 como env var del operador",
      "Rule file con formato §A.4"
    ],
    "category": "feature",
    "priority": "high"
  }],
  "metadata": {
    "operator_id": "jota-batuta",
    "agent_version": "claude-opus-4-6"
  },
  "status": "confirmed"
}
```
