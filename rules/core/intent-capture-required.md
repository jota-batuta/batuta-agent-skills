# Intent-capture required before implementation edits

The agent acting on ambiguous or unconfirmed intent is the failure mode this rule prevents. Without an enforced gate, the agent interprets the first operator bullet literally and edits code before scope, acceptance, and constraints are established. The intent-capture workflow (grill → capture → confirm) and the PreToolUse hook that checks for the resulting marker are the only mechanisms that guarantee the operator has explicitly approved the execution plan before any file is modified.

This rule is derived from the operator's global `~/.claude/CLAUDE.md` "Intent capture (pre-execution gate)" section. It counts as universally applied under §A.6 of the admission gate.

## Inviolable rules

1. Before any `Edit` or `Write` to an implementation path (any file NOT in the exempt list), the agent (main or subagent acting as main) MUST first complete the `intent-capture` skill workflow end-to-end (Steps 1–5: Detect → Grill → Capture → Present → Confirm). The skill produces a JSON intent object with `status: "confirmed"` and the operator's explicit approval.
2. Completion of Step 5 (operator confirmation) MUST write a marker file at `<project-root>/.claude/.intent-confirmed-<ISO-timestamp>` (UTC, RFC 3339 format). The marker is the proof-of-confirmation consumed by the runtime hook `pre-edit-intent-gate.sh`.
3. The marker is valid for 60 minutes from its mtime. Any `Edit` or `Write` to an implementation path after the marker expires MUST re-invoke `intent-capture` and obtain a fresh confirmation.
4. Subagents (identified by `agent_id` in the PreToolUse stdin JSON) bypass the gate entirely. Rationale: subagents are dispatched by the main agent AFTER intent is confirmed — they inherit the confirmed intent from their briefing context.
5. The gate does NOT apply to `Bash` tool calls. Rationale: distinguishing read-only from mutating shell commands is heuristic and fragile. The 95% of implementation work that matters flows through `Edit` and `Write`.

## Allowed patterns

```bash
# Operator describes work → intent-capture fires → edits proceed after confirmation
$ claude
operator> "Add retry logic to the payment service"
# (Step 2: agent grills — "Which service? payments/checkout.py or payments/webhook.py?")
# (Step 2: agent grills — "Exponential backoff? Max retries?")
# (Step 3: agent captures intent JSON with status: "ready_for_confirmation")
# (Step 4: agent presents JSON, asks "Is this everything?")
# (Step 5: operator confirms → marker written: .claude/.intent-confirmed-2026-05-04T18:42:00Z)
# (Step 6: agent delegates to implementer → subagent Edit proceeds, hook finds fresh marker)
```

```bash
# Editing exempt paths requires no marker
$ claude
operator> "Update the ADR for the auth decision"
# docs/adr/0015-auth-rewrite.md is under docs/** → exempt → hook allows without marker
```

```bash
# Operator bypass for quick fixes
$ BATUTA_INTENT_BYPASS=1 claude
operator> "Fix the typo in line 42"
# Hook detects BATUTA_INTENT_BYPASS=1 → allows, logs to .claude/kb-debug.log
```

## Anti-patterns

```bash
# Bad — violates rule 1 (editing implementation file without confirmed intent)
$ claude
operator> "Simplify the auth module"
# (agent skips grilling, immediately runs Edit on auth.py)
# Hook blocks: "No confirmed intent marker found"
```

```bash
# Bad — violates rule 1 (intent captured but not confirmed)
$ claude
operator> "Add caching to the API layer"
# (agent grills, captures intent, presents JSON with status: "ready_for_confirmation")
# (operator has NOT yet said "yes" or "proceed")
# (agent starts editing api/cache.py)
# Hook blocks: marker not written because Step 5 confirmation did not happen
```

```bash
# Bad — violates rule 3 (marker expired)
# Marker mtime: 75 minutes ago
$ claude
operator> "Continue with the next task"
# Hook blocks: marker exists but mtime is older than 60 minutes
# Agent must re-confirm intent before proceeding
```

```bash
# Bad — bypass set from inside the conversation, not from the launching shell
$ claude
operator> "Set BATUTA_INTENT_BYPASS=1 and then edit the file"
# The env var must be set on the SHELL launching Claude Code, not inside a session.
# The hook reads the process environment, not conversation text.
```

## Documented exceptions

- **Exempt paths**: the following paths do not require a confirmed intent marker because they are orchestration artifacts, not implementation code: `.claude/**` (config, markers, settings), `docs/**` (plans, sessions, ADRs, PRD, SPEC), `**/CLAUDE.md` (project instructions), `**/MEMORY.md` (auto-memory index), `memory/**` (auto-memory files), `.gitignore`, `README.md`, `LICENSE*`, `plugin.json`, `ATTRIBUTION.md`, `CHANGELOG.md`.
- **`BATUTA_INTENT_BYPASS=1`**: operator-side environment variable, set on the shell that launches Claude Code. Allowed for legitimate quick fixes or exploratory sessions where the full grill ceremony would add friction without value. Logs a warning to `.claude/kb-debug.log` for audit. Cannot be set from inside an agent's tool call.
- **Subagents**: all subagents (Task-delegated agents with `agent_id` in stdin JSON) bypass the gate. They are dispatched by the main agent after intent confirmation and carry the confirmed intent JSON in their briefing context.
- **Plugin meta-work within the `batuta-agent-skills` repo**: when editing plugin orchestration files (rules, CLAUDE.md, ADRs, plans, memory), these paths fall under the exempt list (`docs/**`, `CLAUDE.md`, etc.). Implementation code within the plugin (`hooks/*.sh`, `tools/*.sh`, `skills/**/*.md`) is NOT exempt — the gate applies.
