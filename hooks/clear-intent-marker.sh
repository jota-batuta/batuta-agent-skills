#!/usr/bin/env bash
# clear-intent-marker.sh (v4.6)
# UserPromptSubmit hook:
#   1. Invalidate intent-capture markers at each operator turn
#   2. Inject routing classifier (~25 tokens) — forces the model to classify
#      (read-only vs action) and resolve dimensions before acting
#
# Fail-soft: any failure logs to kb-debug.log and exits 0.

set +e
trap 'exit 0' ERR

input=$(cat 2>/dev/null || true)

# ============================================================================
# Part 1 — Resolve project root and invalidate markers (v4.2 behavior, preserved).
# ============================================================================

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

if [[ -n "$project_root" ]]; then
  marker_dir="$project_root/.claude"
  if [[ -d "$marker_dir" ]]; then
    shopt -s nullglob
    markers=("$marker_dir"/.intent-confirmed-*)
    shopt -u nullglob
    count=${#markers[@]}
    if [[ $count -gt 0 ]]; then
      rm -f "${markers[@]}" 2>/dev/null
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) clear-intent-marker.sh removed ${count} intent marker(s) from $marker_dir" >> "$marker_dir/kb-debug.log" 2>/dev/null
    fi

    # v4.4: also invalidate routing-confirmed markers at the turn boundary
    shopt -s nullglob
    routing_markers=("$marker_dir"/.routing-confirmed-*)
    shopt -u nullglob
    rcount=${#routing_markers[@]}
    if [[ $rcount -gt 0 ]]; then
      rm -f "${routing_markers[@]}" 2>/dev/null
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) clear-intent-marker.sh removed ${rcount} routing marker(s) from $marker_dir" >> "$marker_dir/kb-debug.log" 2>/dev/null
    fi

    # v4.5: invalidate combined intent+routing markers at the turn boundary
    shopt -s nullglob
    combined_markers=("$marker_dir"/.intent-and-routing-confirmed-*)
    shopt -u nullglob
    ccount=${#combined_markers[@]}
    if [[ $ccount -gt 0 ]]; then
      rm -f "${combined_markers[@]}" 2>/dev/null
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) clear-intent-marker.sh removed ${ccount} combined marker(s) from $marker_dir" >> "$marker_dir/kb-debug.log" 2>/dev/null
    fi
  fi
fi

classifier='Classify: read-only or action? If action, resolve the 6 dimensions (objective, done, scope, constraints, reversibility, safety) from code/context — propose what you can, ask only what you cannot.'

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$classifier" '{
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "additionalContext": $ctx
    }
  }'
else
  cat <<EOJSON
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"$classifier"}}
EOJSON
fi

exit 0
