#!/usr/bin/env bash
# pre-session-context-gate.sh (v4.6)
# PreToolUse hook — enforces context-engineering at session start.
# Blocks Write/Edit/MultiEdit/NotebookEdit AND Bash when no session-context
# marker exists for today's date in the project's .claude/ directory.
#
# Marker contract:
#   `<project-root>/.claude/.session-context-loaded-<YYYY-MM-DD>`
#   Written by `session-start.sh` after successful context injection.
#   Date-scoped: one marker per calendar day (UTC). A new day requires
#   session-start.sh to re-run.
#
# If session-start.sh failed or didn't run (plugin not installed), the model
# can manually invoke /context-engineering and write the marker to unblock.
#
# Exempt paths for Edit/Write (no marker required):
#   .claude/**, docs/**, **/CLAUDE.md, **/MEMORY.md, memory/**, .gitignore,
#   README.md, LICENSE*, plugin.json, ATTRIBUTION.md, CHANGELOG.md
#
# Bash has NO exempt list — every Bash tool call is gated.
#
# Bypass: BATUTA_CONTEXT_GATE_BYPASS=1 (operator-side env var).
#
# Output protocol:
#   exit 0 → allow
#   exit 1 → block (stderr shown to model)

set -uo pipefail

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-session-context-gate.sh WARN: jq not installed; gate is permissive." >&2
  exit 0
fi

# Subagent bypass: subagents inherit session context from the main agent.
event_name=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
agent_id=$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null)
if [[ "$event_name" == "PreToolUse" && -n "$agent_id" ]]; then
  exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
today=$(date -u +%Y-%m-%d)

# ============================================================================
# Bash branch — all Bash tool calls gated.
# ============================================================================
if [[ "$tool_name" == "Bash" ]]; then
  project_root="${CLAUDE_PROJECT_DIR:-}"
  if [[ -z "$project_root" ]]; then
    project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  fi

  if [[ -z "$project_root" ]]; then
    exit 0
  fi

  if [[ "${BATUTA_CONTEXT_GATE_BYPASS:-0}" == "1" ]]; then
    mkdir -p "$project_root/.claude" 2>/dev/null
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BYPASS context-gate(Bash) cwd=$PWD" >> "$project_root/.claude/kb-debug.log" 2>/dev/null
    exit 0
  fi

  marker="$project_root/.claude/.session-context-loaded-$today"
  if [[ -f "$marker" ]]; then
    exit 0
  fi

  cat >&2 <<EOF
RULE violated (session-context gate, v4.6): cannot execute Bash without session context loaded.

No marker found at $marker — the session-start.sh hook writes this marker after injecting project context (KB, vault sessions, active plans).

How to unblock:

  Option A (recommended): Restart the session so session-start.sh runs.
  Option B: Invoke /context-engineering, review the injected context, then
            write the marker manually:
              touch "$project_root/.claude/.session-context-loaded-$today"
  Option C: Restart Claude Code with bypass:
              BATUTA_CONTEXT_GATE_BYPASS=1 claude

Rule: skills/context-engineering/SKILL.md
EOF
  exit 1
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
    echo "pre-session-context-gate.sh: path contains '..' as a segment. Refusing." >&2
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

# Resolve project root
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

if [[ "${BATUTA_CONTEXT_GATE_BYPASS:-0}" == "1" ]]; then
  echo "pre-session-context-gate.sh: BATUTA_CONTEXT_GATE_BYPASS=1 — allowing edit of $file_path" >&2
  mkdir -p "$project_root/.claude" 2>/dev/null
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BYPASS context-gate(Edit) file=$file_path" >> "$project_root/.claude/kb-debug.log" 2>/dev/null
  exit 0
fi

marker="$project_root/.claude/.session-context-loaded-$today"
if [[ -f "$marker" ]]; then
  exit 0
fi

cat >&2 <<EOF
RULE violated (session-context gate, v4.6): cannot edit implementation file:
  $file_path

No marker found at $marker — the session-start.sh hook writes this marker after injecting project context (KB, vault sessions, active plans).

How to unblock:

  Option A (recommended): Restart the session so session-start.sh runs.
  Option B: Invoke /context-engineering, review the injected context, then
            write the marker manually:
              touch "$project_root/.claude/.session-context-loaded-$(date -u +%Y-%m-%d)"
  Option C: Restart Claude Code with bypass:
              BATUTA_CONTEXT_GATE_BYPASS=1 claude

Rule: skills/context-engineering/SKILL.md
EOF
exit 1
