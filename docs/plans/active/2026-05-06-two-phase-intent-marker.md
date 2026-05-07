# Plan: Two-phase intent marker + hook technical debt (v4.6)

## Context

Audit of `batuta-agent-skills` hooks revealed two categories of issues:

**Structural gap (primary):** The model writes its own confirmation markers (`.intent-and-routing-confirmed-*`) via the `Write` tool to `.claude/**` (exempt path in `pre-edit-intent-gate.sh`). A model can skip the grill by writing a fake marker then executing in the same turn — the hook has no way to verify that the operator actually confirmed. The `UserPromptSubmit` event does provide the operator's `prompt` field in stdin JSON (verified via Context7 docs), making a hook-level confirmation detector feasible.

**Technical debt (secondary):** 5 issues — three redundant marker-cleanup blocks in `clear-intent-marker.sh`, dead `find_project_root_and_marker()` function in `pre-edit-intent-gate.sh`, first-write-wins bug in `post-exit-plan-mode.sh`, missing `timeout` for `session-start.sh` in `hooks.json`, `command` bash-builtin variable in `pr-merge-guard.sh`.

**Intended outcome:** Confirmed markers are written exclusively by the hook (external to the model). The model can only write "pending" tokens; the hook promotes them to confirmed only when the operator's actual message contains an explicit confirmation phrase.

---

## Approach: Two-phase marker protocol (v4.6)

New marker lifecycle (replaces single-phase write in SKILL.md Step 5):

1. Model grills → presents intent JSON → writes `.claude/.intent-pending-<ISO>` (contains SHA256 of intent JSON)
2. `clear-intent-marker.sh` on next `UserPromptSubmit`: if `prompt` matches confirmation regex AND `.intent-pending-*` exists → write `.intent-and-routing-confirmed-<ISO>`, delete pending
3. `delegation-guard.sh`: block Write tool calls to `.claude/.intent-and-routing-confirmed-*` → model cannot write confirmed markers directly

Hook-written confirmed markers are immune to model manipulation because hooks run bash directly (not through Claude Code's Write tool; delegation-guard only intercepts tool calls).

---

## Files to modify

### A — Structural fix

| File | Change |
|------|--------|
| `hooks/delegation-guard.sh` | Add `.claude/.intent-and-routing-confirmed-*` to kill-switch blocklist |
| `hooks/clear-intent-marker.sh` | Add Phase 0 (parse prompt), Phase 1b (confirmation detect → promote pending→confirmed), unify 3 cleanup blocks |
| `hooks/pre-edit-intent-gate.sh` | Remove dead `find_project_root_and_marker()` function (lines 58–101) |
| `hooks/pre-task-routing-gate.sh` | Add `-not -empty` to find (line 67) — missing vs pre-edit-intent-gate |
| `skills/intent-capture/SKILL.md` | Step 5: write `.intent-pending-<ISO>` instead of `.intent-and-routing-confirmed-<ISO>`; note hook promotes on operator "dale" |
| `rules/core/intent-capture-required.md` | Rule 3 + Rule 11: update to two-phase protocol; document confirmation-phrase detection |

### B — Technical debt

| File | Change |
|------|--------|
| `hooks/post-exit-plan-mode.sh` | Fix first-write-wins: compare mtime of source vs target; overwrite if source is newer |
| `hooks/hooks.json` | Add `"timeout": 15` to session-start.sh entry |
| `hooks/pr-merge-guard.sh` | Rename `command` → `bash_command` (line 38 and downstream) |

### C — Documentation

| File | Change |
|------|--------|
| `docs/adr/0015-v4.6-two-phase-intent-marker.md` | New ADR: structural gap, chosen approach, rejected alternatives (hook-writes-only vs behavioral-only), consequences |

---

## Confirmation phrase detection spec

In `clear-intent-marker.sh` Phase 1b, the prompt (trimmed, lowercased) must be an EXACT match against the confirmation set — no extra words allowed. This prevents "dale un vistazo" or "dale pero también X" from triggering a false promotion.

```bash
prompt_trimmed=$(echo "$user_prompt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
echo "$prompt_trimmed" | grep -qiE \
  '^(dale|procedé|procede|proceda|go ahead|proceed|yes|okey|ok|confirmo|confirmed|ejecuta|hacelo|hazlo|go|sí|si|approved|listo|aprobado|continue)[.!,]?$'
```

If the operator sends a multi-word message (e.g. answering a grill + confirming), it won't match → pending is cleared → model must re-present intent on the next turn. This is correct behavior.

---

## Routing

| Task | Agent | Reason |
|------|-------|--------|
| All `hooks/` edits (6 files) | `implementer` subagent | `delegation-guard.sh` blocks main from `hooks/*.sh` and `hooks/*.json`; subagent bypasses via `agent_id` |
| `skills/intent-capture/SKILL.md` | `implementer` subagent | Consistent; subagent bypasses pre-edit-intent-gate |
| `rules/core/intent-capture-required.md` | `implementer` subagent | Not in delegation-guard blocklist but in pre-edit-intent-gate scope; subagent bypasses |
| `docs/adr/0015-*.md` | main-direct | `docs/**` is exempt from all gates |

After subagent returns, audit chain runs: `test-engineer` → `code-reviewer` → `security-auditor`.

---

## Verification

```bash
# 1. delegation-guard blocks direct confirmed marker write
#    Attempt: Write tool → .claude/.intent-and-routing-confirmed-2026-...
#    Expected: blocked with kill-switch message

# 2. Two-phase flow — happy path
#    a. Operator sends action request
#    b. Model grills, presents intent JSON, writes .intent-pending-<ISO>
#    c. Model CANNOT execute (no confirmed marker) — gate returns exit 1
#    d. Operator sends "dale"
#    e. UserPromptSubmit hook: detects "dale" + pending → writes confirmed, deletes pending
#    f. Model executes successfully

# 3. Non-confirmation phrase does NOT promote
#    a. Model writes pending marker
#    b. Operator sends "¿qué archivos toca?"
#    c. Hook: message doesn't match regex → clears pending (not confirmed)
#    d. Gate blocks execution → model must re-present

# 4. Technical debt
#    a. post-exit-plan-mode: exit plan mode twice same day, update plan → second write wins
#    b. hooks.json: grep '"timeout"' hooks.json → session-start entry has 15
#    c. pr-merge-guard: grep 'bash_command' hooks/pr-merge-guard.sh → found, no 'command=' except bash_command
```

---

## Open questions

None — scope is fully derived from the audit findings in this session.
