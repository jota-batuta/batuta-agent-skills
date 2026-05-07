#!/usr/bin/env bash
# pre-task-routing-gate.sh (v4.5)
# PreToolUse hook for the Task tool — blocks subagent dispatch unless a
# routing-confirmed marker exists in <project-root>/.claude/.
#
# Closes the discretionary gap where the agent could pick subagent vs
# main-direct silently. The agent must declare routing, the operator must
# approve, and only then write the marker.
#
# v4.5 marker contract — accepts EITHER:
#   - <project-root>/.claude/.intent-and-routing-confirmed-<ISO>  (new combined marker)
#   - <project-root>/.claude/.routing-confirmed-<ISO>             (legacy v4.4)
# Legacy markers are honored for one release cycle to avoid breaking in-flight
# work; they will be removed in v4.6.
#
# Subagent bypass: if the dispatched Task is itself a sub-call from a
# subagent, the agent_id will be present → bypass (matches v4.2/v4.3).
#
# Markers are written by intent-capture Step 5 (combined) on operator approval
# and deleted by clear-intent-marker.sh at every UserPromptSubmit.
#
# Bypass: BATUTA_INTENT_BYPASS=1 (same env var as intent-gate; routing
# is conceptually part of the same gate family).
#
# Output protocol:
#   exit 0 → allow
#   exit 2 → block (stderr shown to model)
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
  marker=$(find "$marker_dir" -maxdepth 1 -not -empty \( -name '.intent-and-routing-confirmed-*' -o -name '.routing-confirmed-*' \) -print -quit 2>/dev/null)
fi

if [[ -n "$marker" ]]; then
  exit 0
fi

cat >&2 <<EOF
RULE violated (routing-gate, v4.5): cannot dispatch Task without operator-approved routing.

No marker found at $marker_dir/.intent-and-routing-confirmed-* (or legacy .routing-confirmed-*) — the agent must declare routing (subagent vs main-direct, with reason per file or scope) and wait for explicit operator approval BEFORE dispatching subagents.

Required workflow (v4.5):
  1. Inside intent-capture Step 5, present intent JSON + routing declaration in ONE combined block.
  2. Operator says "dale" / "procedé" / "approved" / equivalent (single confirmation).
  3. Step 5 writes the combined marker '.intent-and-routing-confirmed-<ISO>'.
  4. Then Task tool calls succeed.

The marker is invalidated at the next operator turn (UserPromptSubmit clears it).
Bypass: BATUTA_INTENT_BYPASS=1 (operator-side env var on launching shell).

Rule: rules/core/intent-capture-required.md (v4.5)
EOF
exit 2
