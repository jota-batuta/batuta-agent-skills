#!/usr/bin/env bash
# pre-session-context-gate.sh (v4.6)
# PreToolUse hook — enforces context-engineering at session start.
# Blocks Write/Edit/MultiEdit/NotebookEdit AND Bash when no session-context
# marker exists for today's date in the project's .claude/ directory.
#
# Marker contract:
#   `<project-root>/.claude/<session_context>-<YYYY-MM-DD>`
#   Written by `session-start.sh` after successful context injection.
#   Date-scoped: one marker per calendar day (UTC). A new day requires
#   session-start.sh to re-run.
#
# If session-start.sh failed or didn't run (plugin not installed), the model
# can manually invoke /context-engineering and write the marker to unblock.
#
# Exempt paths for Edit/Write (no marker required):
#   Configured in plugin-config.json → exempt_paths[]
#
# Bash has NO exempt list — every Bash tool call is gated.
#
# Bypass: env var configured in plugin-config.json → bypass_env_vars.session_context
#
# Output protocol:
#   exit 0 → allow
#   exit 2 → block (stderr shown to model)

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib.sh"

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-session-context-gate.sh WARN: jq not installed; gate is permissive." >&2
  exit 0
fi

# Subagent bypass: subagents inherit session context from the main agent.
if is_subagent "$input"; then
  exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
today=$(date -u +%Y-%m-%d)

# ============================================================================
# Read-only fast-path for Bash — simple read commands bypass the session context gate
# ============================================================================
if [[ "$tool_name" == "Bash" ]]; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
  if [[ -n "$cmd" ]] && is_readonly_bash "$cmd"; then
    exit 0
  fi
fi

# ============================================================================
# Bash branch — all Bash tool calls gated.
# ============================================================================
if [[ "$tool_name" == "Bash" ]]; then
  project_root=$(resolve_project_root)

  if [[ -z "$project_root" ]]; then
    exit 0
  fi

  if is_bypassed "session_context"; then
    mkdir -p "$project_root/.claude" 2>/dev/null
    _log "BYPASS context-gate(Bash) cwd=$PWD"
    exit 0
  fi

  marker="$project_root/.claude/$(marker_name "session_context")$today"
  if [[ -f "$marker" ]]; then
    exit 0
  fi

  bypass_var=$(cfg ".bypass_env_vars.session_context")
  cat >&2 <<EOF
RULE violated (session-context gate, v4.6): cannot execute Bash without session context loaded.

No marker found at $marker — the session-start.sh hook writes this marker after injecting project context (KB, vault sessions, active plans).

How to unblock:

  Option A (recommended): Restart the session so session-start.sh runs.
  Option B: Invoke /context-engineering, review the injected context, then
            write the marker manually:
              touch "$project_root/.claude/$(marker_name "session_context")$today"
  Option C: Restart Claude Code with bypass:
              ${bypass_var}=1 claude

Rule: skills/context-engineering/SKILL.md
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
  echo "pre-session-context-gate.sh: path contains '..' as a segment. Refusing." >&2
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

if is_bypassed "session_context"; then
  echo "pre-session-context-gate.sh: $(cfg ".bypass_env_vars.session_context")=1 — allowing edit of $file_path" >&2
  mkdir -p "$project_root/.claude" 2>/dev/null
  _log "BYPASS context-gate(Edit) file=$file_path"
  exit 0
fi

marker="$project_root/.claude/$(marker_name "session_context")$today"
if [[ -f "$marker" ]]; then
  exit 0
fi

bypass_var=$(cfg ".bypass_env_vars.session_context")
cat >&2 <<EOF
RULE violated (session-context gate, v4.6): cannot edit implementation file:
  $file_path

No marker found at $marker — the session-start.sh hook writes this marker after injecting project context (KB, vault sessions, active plans).

How to unblock:

  Option A (recommended): Restart the session so session-start.sh runs.
  Option B: Invoke /context-engineering, review the injected context, then
            write the marker manually:
              touch "$project_root/.claude/$(marker_name "session_context")$(date -u +%Y-%m-%d)"
  Option C: Restart Claude Code with bypass:
              ${bypass_var}=1 claude

Rule: skills/context-engineering/SKILL.md
EOF
exit 2
