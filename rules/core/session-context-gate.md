---
title: Session context must be loaded before implementation
applies-to: ["bash", "python", "typescript", "markdown"]
last-reviewed: 2026-05-09
enforcement: hook
hook: hooks/pre-session-context-gate.sh
---

# Session context must be loaded before implementation

Stale context is the failure mode this rule prevents. When a session starts without loading the project's knowledge base, vault sessions, and active plans, the agent operates on outdated or missing information. It may overwrite in-flight work, contradict decisions captured in earlier sessions, or repeat discovery that was already completed. The `pre-session-context-gate.sh` hook blocks every Edit, Write, MultiEdit, NotebookEdit, and Bash tool call until a date-scoped marker confirms that today's context has been injected. This forces the agent to see the world before it changes it.

This rule is derived from the operator's global `~/.claude/CLAUDE.md` "Session Context" requirements. Because session context is a prerequisite for all implementation work regardless of project or language, this rule counts as universally applied under §A.6 of the admission gate.

## Inviolable rules

1. No `Edit`, `Write`, `MultiEdit`, or `NotebookEdit` tool call on a non-exempt path is permitted without a `session-context-loaded-<YYYY-MM-DD>` marker file present at `<project-root>/.claude/.session-context-loaded-<YYYY-MM-DD>` for today's UTC date. The marker is written by `session-start.sh` after successful context injection.
2. No `Bash` tool call is permitted without the same marker. Unlike Edit/Write, Bash has NO exempt paths — every Bash invocation is gated unconditionally.
3. Subagents are exempt from this gate. When the hook detects a non-empty `agent_id` in the PreToolUse input, it exits with allow. Subagents inherit session context from the main agent that spawned them; re-gating them would be redundant and would break delegated workflows.
4. Exempt paths for Edit/Write/MultiEdit/NotebookEdit (no marker required):
   - `.claude/**` — orchestration artifacts, markers, debug logs
   - `docs/**` — documentation that may be written during context loading itself
   - `**/CLAUDE.md`, `CLAUDE.md` — project and feature CLAUDE.md files
   - `**/MEMORY.md`, `MEMORY.md` — memory files
   - `memory/**` — memory directory contents
   - `.gitignore`, `README.md`, `LICENSE*`, `plugin.json`, `ATTRIBUTION.md`, `CHANGELOG.md` — repo metadata

## Allowed patterns

```bash
# Normal flow — session-start.sh fires automatically at SessionStart
# (configured as a SessionStart hook in .claude/settings.json)

$ claude
# session-start.sh runs:
#   1. Loads vault context (KB, session journals, active plans)
#   2. Injects project-specific context
#   3. Writes marker: .claude/.session-context-loaded-2026-05-09
# Agent can now Edit/Write/Bash freely for the rest of the day.

> Edit src/main.ts — add the new handler
# (hook checks marker → marker exists for today → allowed)
```

```bash
# Manual unblock — when session-start.sh did not run or failed

$ claude
> /context-engineering
# (skill runs: reviews and injects project context manually)
# Operator writes marker manually after confirming context is loaded:
> touch <project-root>/.claude/.session-context-loaded-$(date -u +%Y-%m-%d)
# Edit/Write/Bash now unblocked.
```

```bash
# Operator-side bypass for emergencies
$ BATUTA_CONTEXT_GATE_BYPASS=1 claude
# All Edit/Write/Bash calls allowed immediately.
# Bypass is logged to .claude/kb-debug.log for audit.
```

```markdown
<!-- Exempt path — editing docs does NOT require the marker -->
<!-- File: docs/architecture.md -->
# No marker needed — docs/** is exempt.
```

## Anti-patterns

```bash
# Bad — violates rule 1 (editing source file without marker)
$ claude
# (session-start.sh failed or was not configured)
> Edit src/handlers/auth.ts — fix the token refresh logic
# Hook blocks: "RULE violated (session-context gate, v4.6): cannot edit
# implementation file: src/handlers/auth.ts"
# No marker at .claude/.session-context-loaded-2026-05-09
```

```bash
# Bad — violates rule 2 (running Bash before context is loaded)
$ claude
# (no marker for today)
> Run npm test to check the current state
# Hook blocks: "RULE violated (session-context gate, v4.6): cannot execute
# Bash without session context loaded."
# Bash has no exempt paths — even read-only commands are gated.
```

```bash
# Bad — stale marker from yesterday
# Marker exists: .claude/.session-context-loaded-2026-05-08
# Today is:      2026-05-09
> Edit src/index.ts — add the import
# Hook blocks: marker is date-scoped to yesterday, not today.
# A new session-start.sh run (or manual marker) is required each calendar day.
```

## Documented exceptions

- **`BATUTA_CONTEXT_GATE_BYPASS=1`**: operator-side environment variable, set on the shell that launches Claude Code. Intended for emergency fixes where restarting the session is impractical, or for CI/automation contexts where session context is injected by other means. The bypass logs a warning to `.claude/kb-debug.log` for audit. Cannot be set from inside an agent's tool call — the design prevents the agent from bypassing its own gate.
- **Subagent bypass**: when the hook detects a non-empty `agent_id` in the PreToolUse JSON input, it allows the call unconditionally. Subagents inherit the session context that was loaded by the main agent. This applies to all subagents regardless of their identity.
- **Missing jq**: if `jq` is not installed, the hook cannot parse the PreToolUse JSON input. It falls back to permissive mode (exit 0) with a warning on stderr. This is a fail-soft design — blocking all tool calls because of a missing dependency would be worse than allowing them without the gate.
- **No project root**: if the hook cannot determine the project root (no `CLAUDE_PROJECT_DIR`, no `.git/` directory found), it allows the call. Files outside a git repository are not subject to session context gating.
