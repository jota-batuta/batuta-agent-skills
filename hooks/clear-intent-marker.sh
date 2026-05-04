#!/usr/bin/env bash
# clear-intent-marker.sh (v4.3)
# UserPromptSubmit hook — TWO responsibilities:
#   1. Invalidate intent-capture markers at the start of each operator turn
#      by deleting <project-root>/.claude/.intent-confirmed-* files.
#   2. Inject a system-reminder via hookSpecificOutput.additionalContext that
#      authoritatively triggers the intent-capture skill on every operator
#      turn — so the gate does not depend on the agent's pattern-matching of
#      operator words. Auto-injection closes the discretion gap that v4.2's
#      reactive blocking alone cannot.
#
# The injected reminder covers three cases:
#   - Action request → grill → capture → confirm → dual-write (marker + intent
#     file under docs/intents/) → declare routing → execute.
#   - Continuation of in-progress intent ("dale", "procedé") → straight to
#     Step 5 (dual-write + declare routing + execute).
#   - Read-only question → answer directly, no grill.
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
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) clear-intent-marker.sh removed ${count} marker(s) from $marker_dir" >> "$marker_dir/kb-debug.log" 2>/dev/null
    fi
  fi
fi

# ============================================================================
# Part 2 — Inject system-reminder (v4.3 auto-injection).
# ============================================================================

reminder='🛑 v4.3 INTENT GATE — operator turn started, prior intent marker invalidated.

Before any Edit/Write/Bash tool call this turn, you MUST invoke the intent-capture skill:

1. Action request ("hacé X", "implementá Y", "agregá Z") → grill (one Q/turn) → capture JSON → present → wait for "sí"/"dale"/"procedé" → write BOTH (a) <project>/.claude/.intent-confirmed-<ISO> marker AND (b) <project>/docs/intents/<YYYY-MM-DD>-<id>-<slug>.md versioned record → declare routing (subagent vs main-direct) and wait for operator approval → then execute.

2. Continuation of intent already presented this turn ("dale", "procedé", "sí") → straight to Step 5 of intent-capture (dual-write marker + intent file → declare routing → execute).

3. Read-only question ("¿qué hace X?", "¿dónde está Y?") → answer directly, no grill.

The pre-edit-intent-gate.sh hook blocks tool calls without a marker — but do NOT wait for it to fire. Grill PROACTIVELY. Routing decisions are NOT at your discretion: declare them and wait for approval.'

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
