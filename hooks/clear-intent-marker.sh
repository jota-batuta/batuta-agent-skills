#!/usr/bin/env bash
# clear-intent-marker.sh (v4.5)
# UserPromptSubmit hook — TWO responsibilities:
#   1. Invalidate intent-capture markers at the start of each operator turn
#      by deleting .intent-confirmed-*, .routing-confirmed-*, and the new
#      v4.5 .intent-and-routing-confirmed-* combined markers.
#   2. Inject a slim (~100 token) system-reminder via additionalContext that
#      points the agent at the canonical rule + skill. The full protocol
#      (grill / capture / present / confirm / routing) lives in
#      rules/core/intent-capture-required.md (loaded once via opencode.json
#      and ~/.claude/CLAUDE.md). Slim reminder = ~500 tokens/turn savings.
#
# Fail-soft: any failure (jq missing, no project root, rm error) logs to
# kb-debug.log and exits 0. UserPromptSubmit must NEVER block the session —
# both the cleanup and the reminder are best-effort.
#
# Source: https://docs.claude.com/en/docs/claude-code/hooks (verified 2026-05-04, Claude Code 2.x)

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

# ============================================================================
# Part 2 — Inject slim system-reminder (v4.5).
# Full protocol lives in rules/core/intent-capture-required.md.
# ============================================================================

reminder='v4.5 intent gate — markers cleared. Action request → run intent-capture skill (trivial vs standard tier per rules/core/intent-capture-required.md), present intent+routing in ONE block, on "dale" write `.intent-and-routing-confirmed-<ISO>` (both tiers). Continuation → write marker. Read-only question → answer directly. Hooks block Edit/Write/Bash/Task without the marker.'

# Emit JSON output protocol for UserPromptSubmit.
# Format: {"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "..."}}

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$reminder" '{
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "additionalContext": $ctx
    }
  }'
elif command -v python3 >/dev/null 2>&1; then
  REMINDER="$reminder" python3 -c '
import json, os
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": os.environ.get("REMINDER", "")
  }
}))
' 2>/dev/null
fi

exit 0
