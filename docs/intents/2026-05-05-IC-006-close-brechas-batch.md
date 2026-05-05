---
id: IC-006
status: confirmed
captured_at: 2026-05-05
confirmed_at: 2026-05-05
operator_id: jota-batuta
agent_version: claude-opus-4-7
category: feature
related_pr: TBD-A,TBD-B
related_branch: chore/close-brechas-IC-006-A,feature/intent-gate-v4.4-routing-marker
related_plan: ""
---

# IC-006 — Close 5 brechas batch + v4.4 routing-gate

## Original ask

> "Debemos eliminar las brechas ya — todas, en ese orden."

Followed by clarification (Item 5 mechanism):

> "B" — proactive hook, parallel to v4.2/v4.3 pattern.

## Refined intent

Close the 5 gaps identified during the session, in the order listed. Split into two PRs by separation of concern:

- **PR-A** (this branch): mechanical cleanup. Items 1, 2, 3, 4. No new enforcement.
- **PR-B** (separate branch): v4.4 — routing-gate hook. Item 5. New runtime enforcement that closes the last discretionary gap (routing decisions).

## Scope per item

### Item 1 — Memory migration (E:\ slug → D:\ slug)

The auto-memory directory is keyed by the sluggified cwd. After the repo move (E:\ → D:\), the new slug `~/.claude/projects/-mnt-d-BATUTA-platform-active-batuta-agent-skills/` did not exist; existing memory entries lived at the old slug `~/.claude/projects/-mnt-e-BATUTA-PROJECTS-batuta-agent-skills/`. Sessions opened from D:\ would not see those entries.

**Action taken**: copied `MEMORY.md`, `feedback_wsl_claude_config.md`, `project_repo_location.md` to the new slug. Old slug intact as backup (no deletion).

```
~/.claude/projects/-mnt-d-BATUTA-platform-active-batuta-agent-skills/memory/
├── MEMORY.md
├── feedback_wsl_claude_config.md
└── project_repo_location.md
```

### Item 2 — PR merges pending (#56, #57)

Operator action only — agent does not merge PRs (PR policy from CLAUDE.md). PRs to merge:

- **#56** — `chore(user-settings): refresh backup post-IC-004 prune` — updates the in-repo backup of `~/.claude/CLAUDE.md` to match the IC-004 prune.
- **#57** — `docs(intents): IC-005 — move plugin from project-scope to user-scope` — persists the IC-005 record for the plugin scope fix.

After both merge, run `/plugin update batuta-agent-skills` (no-op if version unchanged) and verify state.

### Item 3 — v4.3 smoke test in non-BANCOS-EKGS sessions

**Evidence already captured in this session** that v4.3 is firing:

- `/reload-plugins` reported `1 plugin · 13 skills · 14 agents · 8 hooks · 0 plugin MCP servers`.
- The UserPromptSubmit hook `clear-intent-marker.sh` fires on every operator turn — verified by the system-reminder injection visible in this session's prompt context (`🛑 v4.3 INTENT GATE — operator turn started, prior intent marker invalidated`).

**Recommendation for full validation**: operator opens a fresh Claude Code session in any project that is NOT BANCOS EKGS (e.g., this repo from D:\, or any other project), describes a concrete action, and verifies the agent grills before any tool call.

### Item 4 — Vault L2 persistence (deferred)

Goal: promote IC-001 through IC-005 records from `docs/intents/` to curated entries in the Obsidian vault L2 (decisions/playbooks).

**Why deferred**: `kb-curate` skill expects bullets in `docs/sessions/*.md` (journal format), not standalone files in `docs/intents/`. Direct invocation from `docs/intents/` would require either:

1. Adapting the skill workflow (out of scope for this PR).
2. Writing a retrospective session journal entry that references each IC record as a bullet, then running `kb-curate --scope session`.
3. Direct invocation of `kb-curator` agent with custom args (skipping the skill's resolution step).

**Recommendation**: operator runs `/skill batuta-agent-skills:kb-curate --scope all-pending` in a future session after a journal entry exists referencing the IC records. Or invokes `kb-curator` agent directly. The IC records persist in git regardless — the vault L2 is additive, not load-bearing.

### Item 5 — Routing-gate hook (PR-B, v4.4)

**Out of scope for PR-A.** Goes in `feature/intent-gate-v4.4-routing-marker` branch.

Implementation summary (full details in PR-B's IC record if applicable):

- New hook `hooks/pre-task-routing-gate.sh` (PreToolUse matcher `Task`) — blocks subagent dispatch unless `<project>/.claude/.routing-confirmed-<ISO>` marker exists.
- `hooks/clear-intent-marker.sh` updated to ALSO clear `.routing-confirmed-*` markers at every UserPromptSubmit (turn boundary).
- `hooks/hooks.json` registers the new hook under `Task` matcher.
- `skills/intent-capture/SKILL.md` Step 6 updated: agent declares routing → operator approves → ONLY then agent writes the marker → only then can dispatch Task.
- `rules/core/intent-capture-required.md` Rule 7 references the new hook + marker.
- `CLAUDE.md` (project + global) bumps to v4.4 with the new layer.
- `.claude-plugin/plugin.json` 4.3.0 → 4.4.0.

## Routing declaration (for PR-A)

| Trabajo | Quién | Por qué |
|---|---|---|
| Item 1: copy memory files | Main-direct (Bash) | Outside repo, no kill-switch |
| Item 2: doc only | Main-direct | No agent action |
| Item 3: doc only | Main-direct | No agent action |
| Item 4: doc only (deferred) | Main-direct | Skill mismatch, deferred to operator |
| IC-006 record | Main-direct | `docs/**` exempt |

## Acceptance (PR-A)

- IC-006 record persisted at `docs/intents/2026-05-05-IC-006-close-brechas-batch.md`.
- New memory slug populated: `~/.claude/projects/-mnt-d-BATUTA-platform-active-batuta-agent-skills/memory/{MEMORY.md, ...}`.
- Old memory slug intact (backup).
- PR-A opened, not merged.
- PR-B branch created, work in progress (separate PR).

## Outcome

(To be filled on merge of both PRs.)

## Original JSON

```json
{
  "asks": [{
    "id": "IC-006",
    "original_text": "debemos eliminar las brechas ya — todas en ese orden",
    "refined_text": "Cerrar 5 brechas en 2 PRs: PR-A (items 1-4 mechanical) + PR-B (item 5 v4.4 routing-gate)",
    "category": "feature",
    "priority": "high",
    "clarifications": [
      {"question": "Cuáles brechas?", "answer": "Las 5 listadas en orden"},
      {"question": "Mecanismo item 5?", "answer": "Opción B — hook proactivo nuevo con marker .routing-confirmed"}
    ]
  }],
  "metadata": {
    "operator_id": "jota-batuta",
    "agent_version": "claude-opus-4-7"
  },
  "status": "confirmed"
}
```
