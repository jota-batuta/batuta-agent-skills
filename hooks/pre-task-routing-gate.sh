#!/usr/bin/env bash
# pre-task-routing-gate.sh (v4.4)
# PreToolUse hook for the Task tool — blocks subagent dispatch unless a
# routing-confirmed marker exists in <project-root>/.claude/.
#
# Closes the discretionary gap where the agent could pick subagent vs
# main-direct silently. With v4.4, the agent must declare routing,
# the operator must approve, and only then write the marker.
#
# Subagent bypass: if the dispatched Task is itself a sub-call from a
# subagent, the agent_id will be present → bypass (matches v4.2/v4.3).
#
# Marker contract: <project-root>/.claude/.routing-confirmed-<ISO>
#   - Written by intent-capture Step 6 after operator approval.
#   - Deleted by clear-intent-marker.sh at every UserPromptSubmit.
#
# Bypass: BATUTA_INTENT_BYPASS=1 (same env var as intent-gate; routing
# is conceptually part of the same gate family).
#
# Output protocol:
#   exit 0 → allow
#   exit 1 → block (stderr shown to model)
#
# Source: https://docs.claude.com/en/docs/claude-code/hooks (verified 2026-05-05, Claude Code 2.x)

set -uo pipefail
input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-task-routing-gate.sh WARN: jq not installed; gate is permissive." >&2
  exit 0
fi

event_name=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
agent_id=$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null)
if [[ "$event_name" == "PreToolUse" && -n "$agent_id" ]]; then
  exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
if [[ "$tool_name" != "Task" ]]; then
  exit 0
fi

project_root="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$project_root" ]]; then
  project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi
if [[ -z "$project_root" ]]; then
  exit 0
fi

if [[ "${BATUTA_INTENT_BYPASS:-0}" == "1" ]]; then
  mkdir -p "$project_root/.claude" 2>/dev/null
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BYPASS routing-gate(Task)" >> "$project_root/.claude/kb-debug.log" 2>/dev/null
  exit 0
fi

marker_dir="$project_root/.claude"
marker=""
if [[ -d "$marker_dir" ]]; then
  marker=$(find "$marker_dir" -maxdepth 1 -name '.routing-confirmed-*' -print -quit 2>/dev/null)
fi

if [[ -n "$marker" ]]; then
  exit 0
fi

cat >&2 <<EOF
RULE violated (routing-gate, v4.4): cannot dispatch Task without operator-approved routing.

No routing-confirmed marker found at $marker_dir/.routing-confirmed-* — the agent must declare routing (subagent vs main-direct, with reason per file or scope) and wait for explicit operator approval BEFORE dispatching subagents.

Required workflow:
  1. Inside intent-capture Step 6, declare routing in plain language to the operator.
  2. Operator says "dale" / "procedé" / "approved" / equivalent.
  3. Step 6 writes the marker '.routing-confirmed-<ISO>' (analogous to .intent-confirmed).
  4. Then Task tool calls succeed.

The marker is invalidated at the next operator turn (UserPromptSubmit clears it).
Bypass: BATUTA_INTENT_BYPASS=1 (operator-side env var on launching shell).

Rule: rules/core/intent-capture-required.md (Rule 7, v4.4)
EOF
exit 1
