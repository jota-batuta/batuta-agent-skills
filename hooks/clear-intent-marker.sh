#!/usr/bin/env bash
# clear-intent-marker.sh
# UserPromptSubmit hook — invalidates intent-capture markers at the start of each operator turn.
# Deletes <project-root>/.claude/.intent-confirmed-* before the agent processes a new prompt.
#
# This is the per-turn invalidation mechanism (v4.2). Combined with pre-edit-intent-gate.sh,
# it forces a fresh grill+confirm cycle for every operator turn — there is no time-based
# window; the boundary is the operator turn itself.
#
# Fail-soft: any failure logs to kb-debug.log and exits 0. UserPromptSubmit must NEVER
# block the session — cleanup is best-effort.
#
# Source: https://docs.claude.com/en/docs/claude-code/hooks (verified 2026-05-04, Claude Code 2.x)

set +e
trap 'exit 0' ERR

input=$(cat 2>/dev/null || true)

# Resolve project root: prefer $CLAUDE_PROJECT_DIR if set; fall back to walk-up .git/ from cwd.
project_root="${CLAUDE_PROJECT_DIR:-}"

if [[ -z "$project_root" ]]; then
  search_dir="$PWD"
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
fi

if [[ -z "$project_root" ]]; then
  project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi

if [[ -z "$project_root" ]]; then
  exit 0
fi

marker_dir="$project_root/.claude"

if [[ ! -d "$marker_dir" ]]; then
  exit 0
fi

shopt -s nullglob
markers=("$marker_dir"/.intent-confirmed-*)
shopt -u nullglob
count=${#markers[@]}

if [[ $count -gt 0 ]]; then
  rm -f "${markers[@]}" 2>/dev/null
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) clear-intent-marker.sh removed ${count} marker(s) from $marker_dir" >> "$marker_dir/kb-debug.log" 2>/dev/null
fi

exit 0
