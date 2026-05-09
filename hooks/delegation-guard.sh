#!/usr/bin/env bash
# delegation-guard.sh
# PreToolUse hook — kill-switch-only enforcement for the main agent.
# Aligned with Anthropic's platform pattern (v2.7): pre-edit blocks are for hard constraints
# (secrets, plugin self-disable), NOT workflow enforcement. Claude's native delegation judgment
# handles the delegate-vs-edit tradeoff for everything else.
#
# What this hook enforces:
#   HARD-BLOCK (always, regardless of path): kill-switch paths configured in
#   plugin-config.json → kill_switch_paths[] plus confirmed-marker paths.
#
#   ALLOW: everything else, including project source files. Claude decides when to delegate
#   via Task() vs edit directly, per its native judgment.
#
# Subagent bypass: agents bypass this hook entirely via is_subagent().
#
# Failure mode (v2.7): if JSON parsing fails, ALLOW (do not lock the session). The hook's
# purpose is kill-switch protection, not workflow enforcement — a parse error should not
# block work. Exception: if the path explicitly matches a kill-switch pattern after partial
# parse, still block.
#
# Output protocol (Claude Code hooks reference):
#   exit 0 → allow the tool call
#   exit 2 → block the tool call (stderr is shown to the model as the block reason)
#   (this hook uses exit 2 for clarity on kill-switch hits)
#
# Security invariants maintained (regressions MUST be flagged):
#   - file_path and agent_id NEVER reach a shell-execution context (eval/$(...)/backticks).
#     Consumed only by `case` patterns, `echo`/heredoc, and parameter expansion.
#   - Subagent detection requires BOTH non-empty agent_id AND hook_event_name == "PreToolUse"
#     to prevent bypass via stdin spoofing in non-PreToolUse contexts.
#
# Source: https://code.claude.com/docs/en/hooks (verified 2026-04-27, Claude Code 1.x)
# Source: https://code.claude.com/docs/en/permissions (verified 2026-04-27, Claude Code 1.x)

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib.sh"

input=$(cat)

# Fail-soft: jq is required to parse stdin JSON. If missing, allow with warning.
if ! command -v jq >/dev/null 2>&1; then
  echo "delegation-guard.sh WARN: jq not installed; hook is permissive. Install with 'winget install jqlang.jq'." >&2
  exit 0
fi

# Subagent detection via lib.sh — requires BOTH agent_id AND hook_event_name == "PreToolUse".
if is_subagent "$input"; then
  exit 0
fi

# Extract target path. Different tools use different keys.
# Source: https://code.claude.com/docs/en/hooks (verified 2026-04-27, Claude Code 1.x).
# Write/Edit/MultiEdit expose tool_input.file_path; NotebookEdit exposes tool_input.notebook_path.
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)

# If JSON parsing failed or produced no path, allow. The hook's purpose is kill-switch
# protection; a parse error should not block the session. (v2.7 failure-mode flip)
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Defensive normalization: convert backslashes to forward slashes so Windows-shaped paths
# match the same case patterns as POSIX paths.
file_path="${file_path//\\//}"

# Path-traversal guard via lib.sh.
if has_path_traversal "$file_path"; then
  echo "delegation-guard.sh: path contains '..' as a segment (potential traversal). Refusing for safety." >&2
  echo "Path received: $file_path" >&2
  exit 2
fi

# KILL-SWITCH BLOCKLIST: paths the main agent must NEVER write to.
# Configured in plugin-config.json → kill_switch_paths[] plus confirmed-marker paths.
# Subagents that legitimately need to write here (e.g. agent-architect creating
# .claude/agents/<x>.md) bypass this script entirely via is_subagent() above.
if is_kill_switch_path "$file_path"; then
  cat >&2 <<EOF
RULE #0 violated (kill-switch): the main agent cannot modify ${file_path} directly.
This file controls plugin enforcement; modifying it from the main would self-disable safeguards.
Delegate to a subagent (haiku for trivial edits, implementer for substantive changes), or update via the plugin's installation flow.
Use Write to \`$(marker_name "intent_pending")*\` instead — the hook promotes pending to confirmed on operator confirmation.
EOF
  exit 2
fi

# All other paths: ALLOW. Claude uses its native judgment for the delegate-vs-edit decision.
# See docs/adr/0006-trust-native-delegation.md for rationale.
exit 0
