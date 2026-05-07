---
name: hooks-diagnose
description: Diagnose Claude Code hook configuration health: missing scripts, bad permissions, stale markers, and hooks.json integrity.
---

# hooks-diagnose

## Overview

Produce a complete, actionable health report of the hooks system in the current plugin installation. The session-start hook (`hooks-health.sh`) emits a one-line summary on every session; this skill generates the full diagnostic needed to understand and fix any problem it surfaces.

It checks three things: **configuration** (hooks.json is parseable and each entry is internally consistent), **filesystem** (every referenced script exists and has execute permission), and **runtime state** (marker files are present, fresh, or correctly absent).

## When to Use

- A hook gate is blocking a `Write`/`Edit`/`Bash`/`Task` call and the reason is unclear.
- Session start surfaced warnings from `hooks-health.sh` and details are needed.
- `hooks.json` or a hook script was just edited or added.
- Before sharing the plugin or onboarding a new team member.

Do NOT invoke this skill to confirm that hooks work in general — run the Verification commands instead. This skill is for diagnosing a specific problem or doing a post-change audit.

## Process

### Step 1 — Enumerate hooks

Read `hooks/hooks.json`. For each entry, capture and display:

- `event` (e.g. `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`)
- `matcher` — the tool or glob pattern the hook filters on
- `command` — the shell command (extract the script filename)
- `timeout` — if present
- Position in chain (index in array)

Output as a numbered list before the table in Step 4.

### Step 2 — Validate scripts

For each script name extracted in Step 1:

1. Resolve the path as `<plugin-root>/hooks/<script-name>`. The plugin root is determined by `git rev-parse --show-toplevel` when run from inside the repo, or via the `CLAUDE_PLUGIN_ROOT` env var if set.
2. Check existence: `test -f <path>` → **EXISTS** or **MISSING**.
3. Check execute bit: `test -x <path>` → **+x** or **no-x**.
4. Assign status:
   - `PASS` — exists and executable.
   - `WARN` — exists but not executable (`chmod +x` needed).
   - `FAIL` — file does not exist at all.

### Step 3 — Check markers

List all files in `.claude/` (relative to project root, not plugin root) matching these patterns. For each file found, compute its age in minutes from its `mtime` and assign a status:

| Pattern | Fresh threshold | Expected state |
|---|---|---|
| `.authoring-marker-skill-*` | < 60 min | Present only while authoring a skill |
| `.authoring-marker-agent-*` | < 60 min | Present only while authoring an agent |
| `.intent-pending-*` | < 30 min | Present during active intent capture |
| `.intent-and-routing-confirmed-*` | N/A | Should exist only during active tool execution |

Status rules:
- **fresh** — age is within the threshold above.
- **stale** — marker exists but exceeds its threshold. Warn: a stale marker may block the next gate check or indicate an interrupted workflow.
- **unexpected** — `.intent-and-routing-confirmed-*` present outside an active tool execution context (the `clear-intent-marker.sh` hook deletes these at each turn boundary; finding one at diagnostic time is a sign the hook did not run).

If no markers are found in `.claude/`, report `No markers present (clean state)`.

### Step 4 — Output table

Print a summary markdown table:

```
| Hook script                | Event          | Exists | Perms | Status |
|----------------------------|----------------|--------|-------|--------|
| clear-intent-marker.sh     | UserPromptSubmit | ✓    | +x    | PASS   |
| pre-edit-intent-gate.sh    | PreToolUse     | ✓      | +x    | PASS   |
| pre-task-routing-gate.sh   | PreToolUse     | ✓      | +x    | PASS   |
| missing-script.sh          | PostToolUse    | ✗      | —     | FAIL   |
```

Then print a **Marker state** section with one line per marker found (or the clean-state notice).

Close with a **Summary** line:
- `All hooks OK — N scripts checked, 0 failures.`
- `WARN: N issue(s) found — see FAIL/WARN rows above.`

## Anti-Rationalizations

| Excuse | Reality |
|---|---|
| "I can just check `.claude/kb-debug.log`" | The log shows what ran, not what is configured. This skill checks configuration state — existence, permissions, and registered matchers — before any execution. |
| "The session-start hook already warned me" | `hooks-health.sh` emits a one-liner. This skill names the broken scripts, shows the permission bits, and surfaces stale markers with ages so the problem is immediately actionable. |
| "I'll fix it by re-installing the plugin" | Re-install cures missing scripts but does not fix stale markers or incorrect `hooks.json` entries introduced manually. Diagnose first, then decide. |

## Red Flags

- Running this skill when `hooks.json` does not exist — the plugin is not properly installed. Run the plugin setup script first.
- Treating a `WARN` (bad permissions) as acceptable: a hook that cannot execute silently does nothing, leaving gates open or permanently closed.
- Ignoring a **stale** `.intent-pending-*` marker older than 30 minutes: it will cause the intent gate to pass when it should block, hiding missing confirmations.
- Concluding that hooks are healthy based on the table alone when `.intent-and-routing-confirmed-*` markers are **unexpected** — the `clear-intent-marker.sh` hook has likely failed to register or is failing silently.

## Verification

```bash
# hooks.json is valid JSON
python3 -m json.tool hooks/hooks.json >/dev/null && echo "hooks.json OK"

# All hook scripts referenced in hooks.json are present and executable
jq -r '.[].command' hooks/hooks.json | grep -oP "hooks/\K\S+\.sh" | sort -u | \
  while read s; do
    f="hooks/$s"
    [ -f "$f" ] || { echo "MISSING: $f"; continue; }
    [ -x "$f" ] || echo "NO-EXEC: $f"
  done

# Current marker state
ls .claude/.authoring-marker-* .claude/.intent-* 2>/dev/null || echo "No markers"
```
