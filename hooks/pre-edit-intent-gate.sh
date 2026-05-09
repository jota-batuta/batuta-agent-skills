#!/usr/bin/env bash
# pre-edit-intent-gate.sh (v4.6)
# PreToolUse hook — enforces `rules/core/intent-capture-required.md`.
# Blocks Write/Edit/MultiEdit AND Bash on implementation paths when no
# intent-confirmed marker exists in the project's .claude/ directory.
#
# v4.6 changes (vs v4.5):
#   - Read-only Bash fast-path: simple ls/cat/grep/git-status etc. now bypass
#     the marker check. Conservative regex; pipes allowed only between
#     read-only verbs; any of >, ;, &, $, backtick falls through.
#
# v4.5 marker contract — accepts EITHER:
#   - `<project-root>/.claude/<intent_confirmed>-<ISO>`  (new combined marker)
#   - `<project-root>/.claude/<intent_legacy>-<ISO>`     (legacy v4.2-v4.4)
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
#   Configured in plugin-config.json → exempt_paths[]
#
# Bash has NO exempt list — every Bash tool call is gated.
#
# Bypass: env var configured in plugin-config.json → bypass_env_vars.intent
#
# Output protocol:
#   exit 0 → allow
#   exit 2 → block (stderr shown to model)
#
# Source: https://docs.claude.com/en/docs/claude-code/hooks (verified 2026-05-04, Claude Code 2.x)

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib.sh"

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-edit-intent-gate.sh WARN: jq not installed; gate is permissive." >&2
  exit 0
fi

# Subagent bypass: subagents inherit confirmed intent from the main agent.
if is_subagent "$input"; then
  exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# ============================================================================
# Bash branch — all Bash tool calls gated.
# ============================================================================
if [[ "$tool_name" == "Bash" ]]; then
  # Resolve project root via lib.sh.
  project_root=$(resolve_project_root)

  if [[ -z "$project_root" ]]; then
    exit 0  # cannot resolve — fail-soft allow
  fi

  if is_bypassed "intent"; then
    mkdir -p "$project_root/.claude" 2>/dev/null
    _log "BYPASS intent-gate(Bash) cwd=$PWD"
    exit 0
  fi

  # ──────────────────────────────────────────────────────────────────────────
  # Read-only fast-path via lib.sh. Allow simple invocations and pipes of
  # known read-only verbs without a marker.
  # ──────────────────────────────────────────────────────────────────────────
  cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
  if [[ -n "$cmd" ]] && is_readonly_bash "$cmd"; then
    exit 0
  fi

  marker_dir="$project_root/.claude"
  if [[ -d "$marker_dir" ]]; then
    if find_any_marker "$marker_dir" "intent_confirmed" || \
       find_any_marker "$marker_dir" "intent_legacy"; then
      exit 0
    fi
  fi

  cat >&2 <<EOF
RULE violated (intent-capture gate, v4.5): cannot execute Bash without a confirmed intent.

No marker found at $marker_dir/$(marker_name "intent_confirmed")* (or legacy $(marker_name "intent_legacy")*) — the gate applies to non-fast-path Bash tool calls; simple read-only commands are allowed by the conservative fast-path.

Required workflow before any Bash tool call:

  1. The operator describes work → intent-capture skill triggers automatically.
  2. The agent grills (one question per turn) until scope/acceptance are clear.
  3. The agent captures: presents a JSON intent object for confirmation.
  4. The operator confirms ("yes, go ahead", "proceed", "dale").
  5. Step 5 writes the marker. Then Bash/Edit/Write are allowed for this turn.

The marker is automatically invalidated at the next operator turn (UserPromptSubmit
clears it). There is NO time window — the boundary is the operator turn.

To bypass for legitimate quick fixes, restart Claude Code with:

  $(cfg ".bypass_env_vars.intent")=1 claude

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

if has_path_traversal "$file_path"; then
  echo "pre-edit-intent-gate.sh: path contains '..' as a segment. Refusing." >&2
  exit 2
fi

# EXEMPT PATHS — orchestration artifacts, no marker required (from config)
if is_exempt_path "$file_path"; then
  exit 0
fi

# Resolve project root via lib.sh (walk up from file_path's directory).
project_root=$(resolve_project_root "$(dirname "$file_path")")

if [[ -z "$project_root" ]]; then
  project_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null || echo "")
fi

if [[ -z "$project_root" ]]; then
  exit 0
fi

if is_bypassed "intent"; then
  echo "pre-edit-intent-gate.sh: $(cfg ".bypass_env_vars.intent")=1 — allowing edit of $file_path" >&2
  mkdir -p "$project_root/.claude" 2>/dev/null
  _log "BYPASS intent-gate(Edit) file=$file_path"
  exit 0
fi

marker_dir="$project_root/.claude"
if [[ -d "$marker_dir" ]]; then
  if find_any_marker "$marker_dir" "intent_confirmed" || \
     find_any_marker "$marker_dir" "intent_legacy"; then
    exit 0
  fi
fi

cat >&2 <<EOF
RULE violated (intent-capture gate, v4.5): cannot edit implementation file:
  $file_path

No marker found at $marker_dir/$(marker_name "intent_confirmed")* (or legacy $(marker_name "intent_legacy")*) — markers are invalidated at the start of each operator turn (UserPromptSubmit hook).

Required workflow before editing implementation files:

  1. The operator describes work → intent-capture skill triggers automatically.
  2. The agent grills: asks scope, ambiguity, acceptance questions (one per turn).
  3. The agent captures: presents a JSON intent object for confirmation.
  4. The operator confirms ("yes, go ahead", "proceed", "dale").
  5. Step 5 of intent-capture writes the marker. Then edits are allowed.

The marker is invalidated automatically at the next operator turn — no time window.

To bypass for legitimate quick fixes, restart Claude Code with:

  $(cfg ".bypass_env_vars.intent")=1 claude

Rule: rules/core/intent-capture-required.md
EOF
exit 2
