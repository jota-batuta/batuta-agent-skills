#!/usr/bin/env bash
# pre-write-agent-gate.sh
# PreToolUse hook — enforces rule `rules/authoring/agent-authoring-required.md`.
# Blocks Write/Edit/MultiEdit on **/agents/**.md when the path does not already
# exist (creation, not edit) AND the target sits inside the batuta-agent-skills
# plugin repository AND no fresh authoring marker is found.
#
# Marker contract: `${CLAUDE_PLUGIN_ROOT}/.claude/<authoring_agent>-<ISO>`
#   - Written by `skills/batuta-agent-authoring` Step 5 OR by
#     `agents/agent-architect.md` Phase 5.0.
#   - Valid for authoring_marker_ttl_minutes (from config, mtime-based).
#
# Bypass: env var configured in plugin-config.json → bypass_env_vars.agent_authoring
#
# Output protocol:
#   exit 0 → allow the tool call
#   exit 2 → block the tool call (stderr is shown to the model)
#
# Source: https://code.claude.com/docs/en/hooks (verified 2026-04-29, Claude Code 1.x)

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib.sh"

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-write-agent-gate.sh WARN: jq not installed; gate is permissive." >&2
  exit 0
fi

file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
if [[ -z "$file_path" ]]; then
  exit 0
fi

file_path="${file_path//\\//}"

# Path-traversal guard via lib.sh.
if has_path_traversal "$file_path"; then
  echo "pre-write-agent-gate.sh: path contains '..' as a segment. Refusing." >&2
  exit 2
fi

# Match scope: only **/agents/**.md (plugin agents/ AND project-local
# .claude/agents/). Exclude README and other non-agent .md files.
case "$file_path" in
  */agents/README.md|agents/README.md)
    exit 0  # readme is metadata, not an agent
    ;;
  */agents/*.md|agents/*.md)
    : # in scope
    ;;
  *)
    exit 0  # not an agent file
    ;;
esac

if [[ -e "$file_path" ]]; then
  exit 0  # editing existing agent, no marker required
fi

# Resolve the plugin root via lib.sh.
plugin_root=$(resolve_plugin_root "$(dirname "$file_path")")

if [[ -z "$plugin_root" ]]; then
  exit 0  # cannot resolve plugin root, out of scope
fi

# Repo-scope guard for plugin-shipped agents (path contains /agents/ at the
# plugin root, not /.claude/agents/). Project-local agents (<project>/.claude/
# agents/) do not need the origin check — they are governed by the rule once
# the project imports `@.claude/rules/authoring/agent-authoring-required.md`.
case "$file_path" in
  */.claude/agents/*)
    : # project-local, no origin check needed
    ;;
  *)
    origin=$(git -C "$plugin_root" remote get-url origin 2>/dev/null || echo "")
    pattern=$(repo_pattern)
    case "$origin" in
      *${pattern}*|*${pattern}.git*)
        : # in scope
        ;;
      *)
        exit 0  # different plugin, gate does not apply
        ;;
    esac
    ;;
esac

# Operator-side bypass via lib.sh.
if is_bypassed "agent_authoring"; then
  echo "pre-write-agent-gate.sh: $(cfg ".bypass_env_vars.agent_authoring")=1 — allowing creation of $file_path" >&2
  mkdir -p "$plugin_root/.claude" 2>/dev/null
  _log "BYPASS agent-gate file=$file_path"
  exit 0
fi

# Look for a fresh marker via lib.sh (reads TTL from config).
marker_dir="$plugin_root/.claude"
if [[ -d "$marker_dir" ]] && find_fresh_marker "$marker_dir" "authoring_agent"; then
  exit 0
fi

ttl=$(timeout_val "authoring_marker_ttl_minutes")
cat >&2 <<EOF
RULE violated (agent-authoring gate, v3.8): cannot create new agent file at:
  $file_path

No fresh authoring marker found at $marker_dir/$(marker_name "authoring_agent")* (expires after ${ttl} minutes).

Required workflow before creating an agent file:

  Plugin-shipped agent (under agents/ in the plugin repo):
    1. Invoke /skill batuta-agent-authoring and complete its workflow.
    2. Step 5 of the skill writes the marker.

  Project-local specialist (under <project>/.claude/agents/):
    1. Invoke agent-architect via Task. Its Phase 5.0 writes the marker.
    2. Phase 5 then writes the specialist file.

To bypass for legitimate cosmetic edits, restart Claude Code with:

  $(cfg ".bypass_env_vars.agent_authoring")=1 claude

Full rule: $plugin_root/rules/authoring/agent-authoring-required.md
EOF
exit 2
