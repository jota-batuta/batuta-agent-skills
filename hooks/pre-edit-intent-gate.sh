#!/usr/bin/env bash
# pre-edit-intent-gate.sh (v4.5)
# PreToolUse hook — enforces `rules/core/intent-capture-required.md`.
# Blocks Write/Edit/MultiEdit AND Bash on implementation paths when no
# intent-confirmed marker exists in the project's .claude/ directory.
#
# v4.5 marker contract — accepts EITHER:
#   - `<project-root>/.claude/.intent-and-routing-confirmed-<ISO>`  (new combined marker)
#   - `<project-root>/.claude/.intent-confirmed-<ISO>`              (legacy v4.2-v4.4)
# Legacy markers are honored for one release cycle to avoid breaking in-flight
# work; they will be removed in v4.6.
#
# v4.2 changes (vs v4.1):
#   - Bash matcher added: ALL Bash tool calls require a marker (no allow/deny lists).
#   - Time window removed: marker existence is checked, not mtime. The companion
#     `clear-intent-marker.sh` UserPromptSubmit hook invalidates markers at each
#     operator turn boundary.
#
# Markers are written by `skills/intent-capture` Step 5 on operator confirmation
# and deleted by `clear-intent-marker.sh` at the next UserPromptSubmit.
#
# Exempt paths for Edit/Write (no marker required):
#   .claude/**, docs/**, **/CLAUDE.md, **/MEMORY.md, memory/**, .gitignore,
#   README.md, LICENSE*, plugin.json, ATTRIBUTION.md, CHANGELOG.md
#
# Bash has NO exempt list — every Bash tool call is gated.
#
# Bypass: BATUTA_INTENT_BYPASS=1 (operator-side env var).
#
# Output protocol:
#   exit 0 → allow
#   exit 2 → block (stderr shown to model)
#
# Source: https://docs.claude.com/en/docs/claude-code/hooks (verified 2026-05-04, Claude Code 2.x)

set -uo pipefail

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-edit-intent-gate.sh WARN: jq not installed; gate is permissive." >&2
  exit 0
fi

# Subagent bypass: subagents inherit confirmed intent from the main agent.
event_name=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
agent_id=$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null)
if [[ "$event_name" == "PreToolUse" && -n "$agent_id" ]]; then
  exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# ============================================================================
# Bash branch — all Bash tool calls gated.
# ============================================================================
if [[ "$tool_name" == "Bash" ]]; then
  # Resolve project root: $CLAUDE_PROJECT_DIR → cwd via git → none.
  project_root="${CLAUDE_PROJECT_DIR:-}"
  if [[ -z "$project_root" ]]; then
    project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  fi

  if [[ -z "$project_root" ]]; then
    exit 0  # cannot resolve — fail-soft allow
  fi

  if [[ "${BATUTA_INTENT_BYPASS:-0}" == "1" ]]; then
    mkdir -p "$project_root/.claude" 2>/dev/null
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BYPASS intent-gate(Bash) cwd=$PWD" >> "$project_root/.claude/kb-debug.log" 2>/dev/null
    exit 0
  fi

  marker_dir="$project_root/.claude"
  fresh_marker=""
  if [[ -d "$marker_dir" ]]; then
    fresh_marker=$(find "$marker_dir" -maxdepth 1 -not -empty \( -name '.intent-and-routing-confirmed-*' -o -name '.intent-confirmed-*' \) -print -quit 2>/dev/null)
  fi

  if [[ -n "$fresh_marker" ]]; then
    exit 0
  fi

  cat >&2 <<EOF
RULE violated (intent-capture gate, v4.5): cannot execute Bash without a confirmed intent.

No marker found at $marker_dir/.intent-and-routing-confirmed-* (or legacy .intent-confirmed-*) — the gate applies to ALL Bash tool calls (gate-all-Bash, no allow-list).

Required workflow before any Bash tool call:

  1. The operator describes work → intent-capture skill triggers automatically.
  2. The agent grills (one question per turn) until scope/acceptance are clear.
  3. The agent captures: presents a JSON intent object for confirmation.
  4. The operator confirms ("yes, go ahead", "proceed", "dale").
  5. Step 5 writes the marker. Then Bash/Edit/Write are allowed for this turn.

The marker is automatically invalidated at the next operator turn (UserPromptSubmit
clears it). There is NO time window — the boundary is the operator turn.

To bypass for legitimate quick fixes, restart Claude Code with:

  BATUTA_INTENT_BYPASS=1 claude

Rule: rules/core/intent-capture-required.md
EOF
  exit 2
fi

# ============================================================================
# Edit/Write branch — file-path-based with exempt list.
# ============================================================================
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
if [[ -z "$file_path" ]]; then
  exit 0
fi

file_path="${file_path//\\//}"

case "$file_path" in
  ../*|*/..|*/../*|..)
    echo "pre-edit-intent-gate.sh: path contains '..' as a segment. Refusing." >&2
    exit 2
    ;;
esac

# EXEMPT PATHS — orchestration artifacts, no marker required
case "$file_path" in
  */.claude/*|.claude/*)           exit 0 ;;
  */docs/*|docs/*)                 exit 0 ;;
  */CLAUDE.md|CLAUDE.md)           exit 0 ;;
  */MEMORY.md|MEMORY.md)           exit 0 ;;
  */memory/*|memory/*)             exit 0 ;;
  */.gitignore|.gitignore)         exit 0 ;;
  */README.md|README.md)           exit 0 ;;
  */LICENSE*|LICENSE*)              exit 0 ;;
  */plugin.json|plugin.json)       exit 0 ;;
  */ATTRIBUTION.md|ATTRIBUTION.md) exit 0 ;;
  */CHANGELOG.md|CHANGELOG.md)     exit 0 ;;
esac

# Resolve project root: walk up from file_path looking for .git/
project_root=""
search_dir="$(dirname "$file_path")"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [[ -d "$search_dir/.git" ]]; then
    project_root="$search_dir"
    break
  fi
  parent="$(dirname "$search_dir")"
  if [[ "$parent" == "$search_dir" ]]; then
    break
  fi
  search_dir="$parent"
done

if [[ -z "$project_root" ]]; then
  project_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null || echo "")
fi

if [[ -z "$project_root" ]]; then
  exit 0
fi

if [[ "${BATUTA_INTENT_BYPASS:-0}" == "1" ]]; then
  echo "pre-edit-intent-gate.sh: BATUTA_INTENT_BYPASS=1 — allowing edit of $file_path" >&2
  mkdir -p "$project_root/.claude" 2>/dev/null
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BYPASS intent-gate(Edit) file=$file_path" >> "$project_root/.claude/kb-debug.log" 2>/dev/null
  exit 0
fi

marker_dir="$project_root/.claude"
fresh_marker=""
if [[ -d "$marker_dir" ]]; then
  fresh_marker=$(find "$marker_dir" -maxdepth 1 -not -empty \( -name '.intent-and-routing-confirmed-*' -o -name '.intent-confirmed-*' \) -print -quit 2>/dev/null)
fi

if [[ -n "$fresh_marker" ]]; then
  exit 0
fi

cat >&2 <<EOF
RULE violated (intent-capture gate, v4.5): cannot edit implementation file:
  $file_path

No marker found at $marker_dir/.intent-and-routing-confirmed-* (or legacy .intent-confirmed-*) — markers are invalidated at the start of each operator turn (UserPromptSubmit hook).

Required workflow before editing implementation files:

  1. The operator describes work → intent-capture skill triggers automatically.
  2. The agent grills: asks scope, ambiguity, acceptance questions (one per turn).
  3. The agent captures: presents a JSON intent object for confirmation.
  4. The operator confirms ("yes, go ahead", "proceed", "dale").
  5. Step 5 of intent-capture writes the marker. Then edits are allowed.

The marker is invalidated automatically at the next operator turn — no time window.

To bypass for legitimate quick fixes, restart Claude Code with:

  BATUTA_INTENT_BYPASS=1 claude

Rule: rules/core/intent-capture-required.md
EOF
exit 2
