# Intent-capture required before implementation edits — v4.5

The agent acting on ambiguous or unconfirmed intent is the failure mode this rule prevents. Without an enforced gate, the agent interprets the first operator bullet literally and edits code before scope, acceptance, and constraints are established. The intent-capture workflow (detect tier → grill if standard → capture → present → confirm) and the runtime hooks together guarantee the operator has explicitly approved the execution plan before any file is modified.

This rule is derived from the operator's global `~/.claude/CLAUDE.md` "Intent capture (every operator turn)" section. It counts as universally applied under §A.6 of the admission gate.

**v4.5 distillation** (see `docs/adr/0014-v4.5-intent-capture-slim.md`):

- Trivial tier introduced — mechanical threshold skips the grill on atomic / cosmetic changes.
- Single combined confirmation — intent + routing approved together via one "dale", recorded in one `.intent-and-routing-confirmed-<ISO>` marker.
- Discovery commits bundle at slice close — `docs/intents/<id>.md`, plans, and session journals are written immediately but committed bundled with the slice's code, not as standalone commits.
- Enforcement via routing classifier (~25 tokens per turn) + PreToolUse gates — no static rule injection.

## Inviolable rules

1. **Tier assignment** — before any `Edit`/`Write`/`Bash`/`Task` on an implementation path, the agent (main or subagent acting as main) MUST assign a tier:
   - **Trivial** — assigned IFF ALL FIVE conditions hold: ≤3 files touched; ≤20 LOC changed total; no new control flow (no new `if`/`for`/`while`/`try`/`async`); no new external dependency; category in `typo`/`copy`/`css`/`rename`/`comment`/`string-literal`/`version-bump`. The agent MAY skip the grill (Step 2) and present a one-line summary at Step 4.
   - **Standard** — assigned when ANY trivial condition fails. Full grill MUST run.

1bis. **Dimensional routing** — on every action request, the agent resolves six
dimensions from the code and context, proposes what it can, and asks only what
it cannot derive:

| Dimension      | Example resolution                                    |
|----------------|-------------------------------------------------------|
| Objective      | "change #red → #0066cc in Button.tsx:42"              |
| Done           | "button renders blue"                                 |
| Scope          | "Button.tsx only, no other components"                |
| Constraints    | "no new dependencies"                                 |
| Reversibility  | "git revert, no shared state"                         |
| Safety         | "no PII, no auth, no external services"               |

All resolved → propose and confirm in one block. Any unresolved → propose what
is known, ask about the rest. The operator validates or corrects — never fills
from scratch.

2. **Capture and confirm** — the agent MUST complete the `intent-capture` skill workflow end-to-end (Steps 1–6: Detect tier → Grill if standard → Capture → Present → Confirm → Execute). Step 5 produces a JSON intent object with `status: "confirmed"` and the operator's explicit approval, with `tier` declared.

3. **Pending marker** — completion of Step 5 (operator confirmation, single approval covering BOTH intent and routing) MUST write a pending marker file at `<project-root>/.claude/.intent-pending-<ISO-timestamp>` (UTC, RFC 3339 format). The marker must be non-empty — write the SHA-256 hash of the confirmed intent JSON as content. The `clear-intent-marker.sh` UserPromptSubmit hook is the sole writer of `.intent-and-routing-confirmed-*` markers — the model MUST NOT write confirmed markers directly (blocked by `delegation-guard.sh`). The hook promotes the pending marker to confirmed when the operator's next message exactly matches a confirmation phrase. **Legacy markers** `.intent-confirmed-*` and `.routing-confirmed-*` are still accepted by the hooks for one release cycle (v4.5) and removed in v4.6.

4. **Marker validity** — the marker is valid until the next operator turn. The companion hook `clear-intent-marker.sh` (UserPromptSubmit) deletes ALL marker variants before the agent processes a new prompt. There is no time-based expiration — the boundary is the operator turn, not the clock. Any operation after a new prompt arrives MUST re-invoke `intent-capture` and obtain fresh confirmation.

5. **Subagent bypass** — subagents (identified by `agent_id` in the PreToolUse stdin JSON) bypass all gates entirely. Rationale: subagents are dispatched by the main agent AFTER intent is confirmed — they inherit the confirmed intent from their briefing context.

6. **Bash gate scope** — the gate applies to ALL `Bash` tool calls on the main agent. There is no allow-list of read-only commands and no deny-list of mutating patterns — distinguishing read-only from mutating in shell is heuristic and fragile. Gate everything; for genuinely trivial operations (interactive exploration without an action plan), the operator launches Claude Code with `BATUTA_INTENT_BYPASS=1`.

7. **Enforcement architecture (Claude Code)** — three mechanisms, no static rule injection:
   (a) routing classifier injected per turn via UserPromptSubmit (~25 tokens),
   (b) PreToolUse hooks that block Edit/Write/Bash/Task without a valid marker,
   (c) `clear-intent-marker.sh` that invalidates markers at each turn boundary.

8. **Routing declaration in same block as intent** — Step 4 of `intent-capture` MUST present the routing decision (per file or per ask, subagent vs main-direct, with reason) in the SAME block as the intent. The operator's single "dale" approves both. Trivial tier is forced to `main-direct` routing — no subagent allowed. **Routing decisions are NOT at agent discretion**: declaring them, getting explicit approval, and the runtime gate together close the discretion gap.

9. **Persistence (standard tier only)** — Step 5 MUST write the persisted record at `<project-root>/docs/intents/<YYYY-MM-DD>-<id>-<slug>.md` for **standard tier** asks. The file is written to disk immediately but **NOT committed individually** — it bundles into the slice-close commit (Lever 4). For **trivial tier** asks, no `docs/intents/` file is created; the intent is recorded as a one-line entry in the slice's session journal at close. The marker file is written for both tiers.

10. **Commit bundling** — discovery artifacts (`docs/intents/<id>.md`, `docs/plans/active/<file>.md`, `docs/sessions/<file>.md`) are written to their canonical `docs/` paths immediately but committed BUNDLED with the slice's code in the slice-close commit. The user-level rule "Commit after every meaningful change" applies to code; documentation-only churn during discovery is not a meaningful change in itself — it becomes meaningful when bundled with the code that motivated it. Survival to compaction is preserved by the file's presence on disk (`session-start.sh` surfaces uncommitted `docs/` files via `git status`).

11. **Marker integrity** — both the pending marker (`.intent-pending-*`, written by the model) and the confirmed marker (`.intent-and-routing-confirmed-*`, written by the hook) MUST be non-empty. The pending marker contains the SHA-256 hash of the confirmed intent JSON; the hook copies this content when promoting to confirmed. An empty marker (e.g. from `touch`) is rejected by both `pre-edit-intent-gate.sh` and `pre-task-routing-gate.sh` via `-not -empty`. This two-phase design prevents the model from writing a confirmed marker directly — `delegation-guard.sh` blocks any model Write to `.intent-and-routing-confirmed-*` paths.

## Tool-portable invariants vs Claude-Code-specific enforcement

The protocol shape (tier assignment, grill-if-standard, single combined confirmation, commit bundling) is **tool-portable** — it applies identically in Claude Code, opencode, and any agent runtime that imports this rule.

The marker mechanism (`.intent-and-routing-confirmed-*` files, hook gating) is **Claude-Code-specific** — opencode does not write or read marker files because it has no PreToolUse hooks. Opencode self-enforces the protocol by following Steps 1–6 of the skill.

| Aspect | Claude Code | Opencode (and tools without PreToolUse) |
|---|---|---|
| Tier assignment (Step 1b) | Self-enforced by agent per Rule 1 | Self-enforced by agent per Rule 1 |
| Grill if standard (Step 2) | Self-enforced; marker hook backstops | Self-enforced |
| Single combined presentation (Step 4) | Self-enforced | Self-enforced |
| Operator confirmation (Step 5) | Self-enforced | Self-enforced |
| Marker write (Step 5) | **Required** — consumed by hooks | **Skipped** — no hooks to consume it |
| `docs/intents/<id>.md` write (Step 5, standard tier) | Self-enforced | Self-enforced |
| Commit bundling (Step 6+) | Self-enforced | Self-enforced |
| Per-turn routing classifier | **Yes** (~25 tokens via UserPromptSubmit) | **No** — self-enforced |
| `BATUTA_INTENT_BYPASS=1` env var | Honored by hooks | Not applicable (no enforcement to bypass) |

## Allowed patterns

```bash
# Standard tier — operator describes ambiguous work → full grill → combined confirm → execute
$ claude
operator> "Add retry logic to the payment service"
# (Step 1: action request)
# (Step 1b: tier=standard — multi-file scope, control flow likely, no atomic category)
# (Step 2: grill — "Which service? payments/checkout.py or payments/webhook.py?")
# (Step 2: grill — "Exponential backoff? Max retries?")
# (Step 3: capture intent JSON with tier:standard, routing per file)
# (Step 4: present JSON + routing table in ONE block)
# (Step 5: operator says "dale" → single marker written: .intent-and-routing-confirmed-2026-05-05T17:00:00Z, docs/intents/IC-013-... written to disk uncommitted)
# (Step 6: delegate to implementer subagent with confirmed intent JSON)
```

```bash
# Trivial tier — atomic typo fix
$ claude
operator> "Fix the typo on line 42 of README.md — 'recieve' → 'receive'"
# (Step 1: action request)
# (Step 1b: tier=trivial — 1 file, 1 LOC, no control flow, no dep, category=typo)
# (Step 2: SKIPPED)
# (Step 3: capture JSON in memory, tier:trivial, routing:main-direct)
# (Step 4: one-liner: "Trivial tier — typo: receive on README.md:42. Routing: main-direct. ¿Dale?")
# (Step 5: operator says "dale" → marker written, NO docs/intents file)
# (Step 6: agent runs Edit main-direct, audit chain at slice close)
```

```bash
# Editing exempt paths requires no marker
$ claude
operator> "Update the ADR for the auth decision"
# docs/adr/0015-auth-rewrite.md is under docs/** → exempt → hook allows without marker
```

```bash
# Operator bypass
$ BATUTA_INTENT_BYPASS=1 claude
operator> "Fix the typo in line 42"
# Hook detects BATUTA_INTENT_BYPASS=1 → allows, logs to .claude/kb-debug.log
```

## Anti-patterns

```bash
# Bad — violates rules 2-3 (editing implementation file without confirmed intent or marker)
$ claude
operator> "Simplify the auth module"
# (agent skips grilling, immediately runs Edit on auth.py)
# Hook blocks: "No combined or legacy marker found"
```

```bash
# Bad — violates rule 1 (mis-classified trivial)
$ claude
operator> "Rename foo to bar across the codebase"
# (agent declares tier:trivial because category=rename)
# But: 8 files, 60 LOC — fails the ≤3-files and ≤20-LOC conditions.
# Tier MUST be standard. Full grill required.
```

```bash
# Bad — violates rule 8 (declaring routing silently in a separate turn)
$ claude
operator> "Add caching to the API layer"
# (agent grills, captures intent, presents JSON without routing)
# (operator says "dale" — but this only confirms intent, not routing)
# (agent then dispatches Task to a subagent without a separate routing declaration)
# Hook blocks: marker is .intent-confirmed-* (legacy single-purpose) — Task gate sees no .routing-confirmed-* and no combined marker.
# Correct: present intent + routing table in ONE block at Step 4; single "dale" approves both; combined marker covers both gates.
```

```bash
# Bad — violates rule 10 (committing the intent doc as a standalone commit)
$ git add docs/intents/IC-013-add-cache.md
$ git commit -m "docs(intents): IC-013 add cache"
# Lever 4 says: write to disk, do NOT commit until slice close.
# The intent doc bundles with the slice's last code change in one commit.
```

```bash
# Bad — violates rule 4 (marker reused across turns)
# Marker timestamp: 2026-05-05T15:00:00Z
# Operator sends new turn at 2026-05-05T15:01:00Z
# clear-intent-marker.sh deletes the marker on UserPromptSubmit.
# Agent must re-confirm intent before proceeding — there is no time window, the boundary is the turn.
```

```bash
# Bad — violates rule 11 (fabricated empty marker)
touch .claude/.intent-and-routing-confirmed-2026-05-06T00:00:00Z
# Hook rejects: marker is empty.
```

```bash
# Bad — bypass set from inside the conversation, not from the launching shell
$ claude
operator> "Set BATUTA_INTENT_BYPASS=1 and then edit the file"
# The env var must be set on the SHELL launching Claude Code, not inside a session.
# The hook reads the process environment, not conversation text.
```

## Documented exceptions

- **Exempt paths**: the following paths do not require a confirmed intent marker because they are orchestration artifacts, not implementation code: `.claude/**` (config, markers, settings), `docs/**` (plans, sessions, ADRs, intents, PRD, SPEC), `**/CLAUDE.md` (project instructions), `**/MEMORY.md` (auto-memory index), `memory/**` (auto-memory files), `.gitignore`, `README.md`, `LICENSE*`, `plugin.json`, `ATTRIBUTION.md`, `CHANGELOG.md`.
- **`BATUTA_INTENT_BYPASS=1`**: operator-side environment variable, set on the shell that launches Claude Code. Allowed for legitimate quick fixes or exploratory sessions where even the trivial tier would add friction. Logs a warning to `.claude/kb-debug.log` for audit. Cannot be set from inside an agent's tool call.
- **Subagents**: all subagents (Task-delegated agents with `agent_id` in stdin JSON) bypass the gate. They are dispatched by the main agent after intent confirmation and carry the confirmed intent JSON in their briefing context.
- **Plugin meta-work within the `batuta-agent-skills` repo**: when editing plugin orchestration files (rules, CLAUDE.md, ADRs, plans, intents, memory), these paths fall under the exempt list (`docs/**`, `CLAUDE.md`, etc.). Implementation code within the plugin (`hooks/*.sh`, `tools/*.sh`, `skills/**/*.md`) is NOT exempt — the gate applies.
- **Legacy markers (deprecation window)**: `.intent-confirmed-*` and `.routing-confirmed-*` markers are honored by the hooks for one release cycle (v4.5) to avoid breaking in-flight work mid-upgrade. They are removed in v4.6 — the agent should write only the combined marker `.intent-and-routing-confirmed-*`.
