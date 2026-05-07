# intent-capture v4.5 — token & ceremony slim-down

## Context

The v4.4 intent + routing gate works (intent always captured, routing always declared, runtime enforcement closes both discretion gaps), but the operator reports four token/time costs in real use:

1. **Verbose per-turn reminder** — `hooks/clear-intent-marker.sh` injects ~600 tokens of system-reminder on every operator turn. The reminder duplicates content already in `CLAUDE.md`.
2. **Double confirmation** — every action requires intent confirmation, then a second routing confirmation. Two round-trips before any tool call.
3. **Full tunnel for trivial fixes** — a typo correction goes through grill → JSON capture → present → confirm → routing declare → confirm → execute. Same ceremony as a multi-module refactor.
4. **Commit-per-discovery-artifact** — every confirmed intent commits a `docs/intents/<id>.md` separately; plans, session journals, status updates each produce their own commit. A 1-hour slice produces 6–10 commits, half of which are discovery, not code.

Outcome: a v4.5 release of the intent-capture stack that preserves the survival-after-compaction guarantee, the runtime enforcement of intent+routing approval (in Claude Code), the audit trail in `docs/intents/`, **and full opencode interop**, while cutting per-turn token cost by ~500 tokens, halving the confirmation round-trips on standard work, introducing a trivial tier with a one-line confirmation path, and reducing slice-level commits by 60–70%.

## Opencode interop constraint (binding)

Opencode consumes the canonical files directly via two mechanisms:

- `opencode.json` imports `rules/core/intent-capture-required.md` as an instruction line — the rule file is the spec opencode reads.
- `.opencode/skills` is a symlink to `../skills` (verified) — the canonical `skills/intent-capture/SKILL.md` is what opencode loads. Same pattern for `.opencode/agents` and `.opencode/commands`.

Implications for each lever:

- **Lever 1 (slim reminder)** is Claude-Code-only — opencode never runs `clear-intent-marker.sh` and never sees the injected reminder. Pure win for Claude Code, zero impact on opencode.
- **Lever 2 (combined marker)** has two facets: (a) the marker file write/read is hook-gated and Claude-Code-only; opencode does not produce or consume the marker. (b) the *protocol shape* — single combined intent+routing presentation, single "dale" — applies identically in both tools and is described in the rule file in tool-agnostic language. The rule MUST describe the protocol as the contract and the marker as Claude Code's specific enforcement mechanism, not as a universal requirement.
- **Lever 3 (trivial tier)** is pure rule-based; identical behavior in both tools. The agent self-disciplines per the rule and the skill.
- **Lever 4 (commit bundling)** is pure git policy; identical in both tools.

The rule file v4.5 rewrite MUST stay readable as a self-contained spec without assuming hook enforcement. The current v4.4 file already does this gracefully (the contract is in the rules, hooks are referenced as Claude Code's enforcement). v4.5 keeps that pattern and adds an explicit "Tool-portable invariants vs Claude-Code-specific enforcement" subsection so opencode users see clearly which parts they self-enforce.

## Recommended approach (four bundled levers)

### Lever 1 — Slim the auto-injected reminder

`hooks/clear-intent-marker.sh` lines 83–93. The reminder shrinks from ~600 to ~100 tokens. New body keeps only the three-case decision tree (action / continuation / read-only) and the two pointer-references to `CLAUDE.md` and `rules/core/intent-capture-required.md`. The detailed expansion of each path moves into the rule file (read once, cached). The marker-cleanup logic at lines 55–77 stays intact.

### Lever 2 — Collapse intent + routing into a single combined marker

- New marker name: `.intent-and-routing-confirmed-<ISO>`.
- The agent presents intent JSON **and** routing declaration in a single block; the operator approves both with one "dale".
- `hooks/pre-edit-intent-gate.sh` and `hooks/pre-task-routing-gate.sh` are updated to scan for the new combined marker. The two old marker names (`.intent-confirmed-*`, `.routing-confirmed-*`) keep being recognized for one release cycle to avoid breaking in-flight work.
- `hooks/clear-intent-marker.sh` deletes the new combined marker on turn boundary (its existing cleanup loop just adds the new glob).

### Lever 3 — Trivial tier in `intent-capture`

Threshold (mechanical, declared by the agent in the JSON intent as `tier: trivial`):

- ≤3 files touched
- ≤20 LOC changed total
- No new control flow (no new `if`/`for`/`while`/`try`/`async` introductions)
- No new external dependency
- Category in: `typo`, `copy`, `css`, `rename`, `comment`, `string-literal`, `version-bump`

If all five conditions hold → trivial tier:
- Skip Step 2 grill (no questions).
- Step 4 presents a one-line summary instead of the full JSON.
- Step 5 still writes the combined marker, but **no `docs/intents/<file>.md`** is persisted. The intent is captured in the slice's session journal at close (Lever 4) as a one-line entry.
- Step 7 routing is implicit `main-direct` for trivial tier (no subagent allowed).

If any condition fails → standard tier with full grill (today's behavior, minus Lever 2's collapsed confirmation).

### Lever 4 — Bundle discovery commits at slice close

Discovery artifacts (`docs/intents/<id>.md`, `docs/plans/active/<file>.md`, `docs/sessions/<file>.md`) are **written to disk immediately** at their existing canonical paths under `docs/`. They are **not committed individually**.

At slice close, a single commit (typically the same one that ships the last code change, or a final `docs: close slice <id>` if the slice ended without code) stages and commits:
- The intent file(s) created during the slice
- The plan file (or its move from `docs/plans/active/` to `docs/plans/archive/`)
- The session journal

Survival to compaction: the file is on disk at its real `docs/` path; `session-start.sh` already runs `git status` and surfaces uncommitted files in `docs/intents/`, `docs/plans/`, `docs/sessions/` — the next session sees them.

Survival to session death: the file persists on disk untracked; the next session inherits via `git status`.

The user-level rule "Commit after every meaningful change" still holds for code; documentation-only churn during discovery is not a meaningful change in itself — it becomes meaningful when bundled with the code that motivated it.

## Files to modify

- `hooks/clear-intent-marker.sh` — shrink injected reminder; add new combined marker glob to cleanup loop.
- `hooks/pre-edit-intent-gate.sh` — accept combined marker; keep recognition of old markers for one release.
- `hooks/pre-task-routing-gate.sh` — accept combined marker; keep recognition of old.
- `skills/intent-capture/SKILL.md` — add trivial tier branch; update Step 5 to write combined marker; update Step 7 routing to integrate into Step 5; update commit policy section to reference Lever 4.
- `rules/core/intent-capture-required.md` — update rules 1, 7, 8 for combined marker, trivial tier, deferred commit policy. Renumber as needed; bump version header to v4.5.
- `~/.claude/CLAUDE.md` — update "Intent capture (every operator turn)" section: combined confirmation, trivial tier reference, commit-bundling policy. Update "Git" section to clarify "meaningful change" excludes standalone discovery commits.
- `CLAUDE.md` (project) — bump v4.4 → v4.5 in the "intent-capture (enforced)" subsection; add one paragraph on trivial tier and commit bundling.
- `AGENTS.md` (cross-tool master) — update the intent-capture section to reflect v4.5 protocol (single combined presentation, trivial tier, commit bundling). Use MUST/NEVER imperative tone (per cross-tool enforcement convention for tools without hooks). Mark explicitly which parts are tool-portable invariants vs Claude-Code-specific hook enforcement.
- `.opencode/agents/AGENTS.md.template` — if the template diverges from the rendered `AGENTS.md`, update both; otherwise the symlinked structure already covers it.
- `docs/adr/0014-v4.5-intent-capture-slim.md` — new ADR documenting the four levers, why each was needed, why the chosen designs (single marker, mechanical threshold, bundled commits) over rejected alternatives, and how each lever maps to Claude Code vs opencode enforcement.

## Reused functions and existing utilities

- Marker write/clean helpers: existing inline shell in `hooks/clear-intent-marker.sh:55-77` is the template; the new combined-marker cleanup is the same loop with a new glob.
- The `git status --porcelain` survey in `hooks/session-start.sh` already detects uncommitted `docs/` files — Lever 4's recovery path uses it as-is.
- The intent JSON shape in `skills/intent-capture/SKILL.md` Step 3 keeps its schema; only a `tier: "trivial" | "standard"` field is added.
- The audit chain (`test-engineer` → `code-reviewer` → `security-auditor`) in `docs/DELEGATION-RULE.md` already short-circuits on a clean tree (NOT-APPLICABLE). Trivial tier inherits this behavior — no separate audit-chain change needed.

## Verification

1. **Reminder slim** — measure token count of `clear-intent-marker.sh`'s `reminder` heredoc before/after. Target: ≤120 tokens. Verify with a fresh session that the system-reminder still triggers correct intent-capture invocation on a clear action request.

2. **Combined marker** — start a new session, give an action request, accept intent+routing in a single "dale", confirm `.intent-and-routing-confirmed-*` exists in `.claude/`, confirm subsequent `Edit` and `Task` calls succeed without re-confirmation. Repeat with old-style two-step confirmation; both must work during the deprecation window.

3. **Trivial tier** — give an action that meets all five conditions (e.g., "fix the typo in line 42 of README.md"). Verify: no grill questions, one-line confirmation, marker written, edit executes, no `docs/intents/` file created, slice-close session journal records the change as a one-liner.

4. **Trivial tier escapes** — give an action that fails one condition (e.g., "rename foo to bar across 5 files"). Verify: agent declares `tier: standard`, full grill runs, `docs/intents/` file IS created.

5. **Commit bundling** — run a complete slice end-to-end. Count commits via `git log --oneline <branch> ^main`. Target: ≤3 commits for a slice that ships 1 logical change (intent + plan + code + session bundled into 1–2 final commits).

6. **Survival to compaction** — start a slice, get to mid-grill or post-confirmation but pre-commit, force a context compaction (or simulate by starting a fresh session). Verify next session reads the in-flight `docs/intents/<file>.md` via `session-start.sh` and resumes correctly.

7. **Static contract validators** — `bash tests/v2.5-validators/run.sh` must still pass after rule renumbering.

8. **Opencode interop sweep** — start an opencode session against this repo with the v4.5 rule loaded via `opencode.json`. Issue (a) a trivial-tier action (typo fix), (b) a standard-tier action (multi-file refactor). Verify in both: agent presents intent+routing in a single combined block, awaits one confirmation, executes correctly. No marker files are produced (correct — opencode has no hook to enforce), but the protocol shape matches Claude Code's behavior. The `docs/intents/` file is created on standard tier and absent on trivial tier in both tools.

9. **AGENTS.md cross-tool re-read** — verify the updated AGENTS.md uses MUST/NEVER imperative language (no SHOULD/CONSIDER) and that the "Tool-portable vs Claude-Code-specific" boundary is explicit. A naive opencode user reading AGENTS.md alone must be able to follow the intent-capture protocol without confusion about the hook mechanism.

## Out of scope

- Audit chain restructuring. Trivial tier inherits the existing NOT-APPLICABLE-on-clean-tree behavior; no change to `agents/test-engineer.md`, `agents/code-reviewer.md`, `agents/security-auditor.md`.
- `kb-pipeline` / per-commit KB hook changes. Those operate post-commit and are unaffected by commit volume changes upstream — fewer commits just means fewer KB invocations.
- The five other gates (skill-authoring, agent-authoring, rule-authoring, delegation-guard, pr-merge-guard). They remain in their current form.
- Backwards-compatibility shim for the two old markers beyond one release cycle. After v4.6 the old marker names are removed.
