#!/usr/bin/env bash
# pre-edit-intent-gate.sh
# PreToolUse hook — enforces `rules/core/intent-capture-required.md`.
# Blocks Write/Edit/MultiEdit on implementation paths when no fresh
# intent-confirmed marker exists in the project's .claude/ directory.
#
# Marker contract: `<project-root>/.claude/.intent-confirmed-<ISO>`
#   - Written by `skills/intent-capture` Step 5 (on operator confirmation).
#   - Valid for 60 minutes (mtime-based, not filename-based).
#
# Exempt paths (no marker required):
#   .claude/**       — config, markers, settings
#   docs/**          — plans, sessions, ADRs
#   **/CLAUDE.md     — project instructions
#   **/MEMORY.md     — auto-memory index
#   memory/**        — auto-memory files
#   .gitignore       — housekeeping
#   README.md        — documentation
#   LICENSE*         — license files
#   plugin.json      — plugin manifest
#   ATTRIBUTION.md   — vendored attribution
#   CHANGELOG.md     — changelog
#
# Bypass: BATUTA_INTENT_BYPASS=1 (operator-side env var).
#
# Output protocol:
#   exit 0 → allow the tool call
#   exit 1 → block the tool call (stderr shown to model)
#
# Source: https://code.claude.com/docs/en/hooks (verified 2026-05-04, Claude Code 1.x)

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

file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
if [[ -z "$file_path" ]]; then
  exit 0
fi

file_path="${file_path//\\//}"

case "$file_path" in
  ../*|*/..|*/../*|..)
    echo "pre-edit-intent-gate.sh: path contains '..' as a segment. Refusing." >&2
    exit 1
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
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BYPASS intent-gate file=$file_path" >> "$project_root/.claude/kb-debug.log" 2>/dev/null
  exit 0
fi

marker_dir="$project_root/.claude"
fresh_marker=""
if [[ -d "$marker_dir" ]]; then
  fresh_marker=$(find "$marker_dir" -maxdepth 1 -name '.intent-confirmed-*' -mmin -60 -print -quit 2>/dev/null)
fi

if [[ -n "$fresh_marker" ]]; then
  exit 0
fi

cat >&2 <<EOF
RULE violated (intent-capture gate): cannot edit implementation file:
  $file_path

No confirmed intent marker found at $marker_dir/.intent-confirmed-* (markers expire after 60 minutes).

Required workflow before editing implementation files:

  1. The operator describes work → intent-capture skill triggers automatically.
  2. The agent grills: asks scope, ambiguity, acceptance questions (one per turn).
  3. The agent captures: presents a JSON intent object for confirmation.
  4. The operator confirms ("yes, go ahead", "proceed", "dale").
  5. Step 5 of intent-capture writes the marker. Then edits are allowed.

To bypass for legitimate quick fixes, restart Claude Code with:

  BATUTA_INTENT_BYPASS=1 claude

Rule: rules/core/intent-capture-required.md
EOF
exit 1
