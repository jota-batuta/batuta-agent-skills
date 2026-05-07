#!/usr/bin/env bash
# clear-intent-marker.sh (v4.6)
# UserPromptSubmit hook implementing the two-phase intent marker protocol:
#   Phase 0: Parse operator prompt from stdin JSON.
#   Phase 1: Promote .intent-pending-* → .intent-and-routing-confirmed-* if
#            the prompt is an exact confirmation phrase AND a pending marker exists.
#            The hook is the sole writer of confirmed markers (v4.6).
#   Phase 2: Clear all stale markers. If promoted: keep the new confirmed marker,
#            clear only legacy types. If not: clear everything.
#   Phase 3: Inject routing classifier (~25 tokens).
#
# Fail-soft: any failure logs to kb-debug.log and exits 0.

set +e
trap 'exit 0' ERR

input=$(cat 2>/dev/null || true)

# ============================================================================
# Phase 0 — Parse operator prompt from stdin JSON (UserPromptSubmit provides
# the user's message in the "prompt" field).
# ============================================================================
user_prompt=""
if command -v jq >/dev/null 2>&1; then
  user_prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null || true)
fi

# ============================================================================
# Part 1 — Resolve project root.
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
    promoted=0

    # ============================================================================
    # Phase 1 — Two-phase promotion: pending → confirmed.
    # Requires BOTH:
    #   a) operator prompt exactly matches a confirmation phrase, AND
    #   b) a .intent-pending-* file exists in the marker dir.
    # ============================================================================
    if command -v jq >/dev/null 2>&1 && [[ -n "$user_prompt" ]]; then
      prompt_trimmed=$(echo "$user_prompt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      # Use bash [[ =~ ]] — $ is end-of-string, not end-of-line (unlike grep -E).
      # This prevents multi-line prompt injection from triggering a false confirmation.
      if [[ "$prompt_trimmed" =~ ^(dale|procedé|procede|proceda|go[[:space:]]+ahead|proceed|yes|okey|ok|confirmo|confirmed|ejecuta|hacelo|hazlo|go|sí|si|approved|listo|aprobado|continue)[.!,]?$ ]]; then
        shopt -s nullglob
        pending_markers=("$marker_dir"/.intent-pending-*)
        shopt -u nullglob
        if [[ ${#pending_markers[@]} -gt 0 ]]; then
          iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
          confirmed_marker="$marker_dir/.intent-and-routing-confirmed-${iso}"
          if cp "${pending_markers[0]}" "$confirmed_marker" 2>/dev/null; then
            promoted=1
            rm -f "${pending_markers[@]}" 2>/dev/null
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) clear-intent-marker.sh promoted ${#pending_markers[@]} pending marker(s) to confirmed: $confirmed_marker" >> "$marker_dir/kb-debug.log" 2>/dev/null
          else
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) clear-intent-marker.sh: copy pending→confirmed failed" >> "$marker_dir/kb-debug.log" 2>/dev/null
          fi
        fi
      fi
    fi

    # ============================================================================
    # Phase 2 — Clear stale markers (unified — replaces 3 separate blocks).
    # If promoted: keep the newly written confirmed marker; clear legacy only.
    # If not promoted: clear all (confirmed + pending + legacy).
    # ============================================================================
    shopt -s nullglob
    if [[ $promoted -eq 1 ]]; then
      stale_markers=(
        "$marker_dir"/.intent-confirmed-*
        "$marker_dir"/.routing-confirmed-*
        "$marker_dir"/.intent-pending-*
      )
    else
      stale_markers=(
        "$marker_dir"/.intent-confirmed-*
        "$marker_dir"/.routing-confirmed-*
        "$marker_dir"/.intent-and-routing-confirmed-*
        "$marker_dir"/.intent-pending-*
      )
    fi
    shopt -u nullglob

    count=${#stale_markers[@]}
    if [[ $count -gt 0 ]]; then
      rm -f "${stale_markers[@]}" 2>/dev/null
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) clear-intent-marker.sh cleared ${count} stale marker(s) from $marker_dir" >> "$marker_dir/kb-debug.log" 2>/dev/null
    fi
  fi
fi

# ============================================================================
# Phase 3 — Inject routing classifier (~25 tokens).
# ============================================================================
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
