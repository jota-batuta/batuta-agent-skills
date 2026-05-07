#!/usr/bin/env bash
# hooks-health.sh
# SessionStart hook — fast integrity check for the hooks subsystem.
# Validates: hooks.json is valid JSON, every registered .sh script exists
# and has +x, no stale .intent-pending-* markers from a previous session,
# and jq availability (soft warn if absent; python3 covers its role).
#
# Fail-soft contract: always exits 0. A broken health check must never
# block a session start.

set -euo pipefail
trap 'exit 0' ERR

# ---------------------------------------------------------------------------
# Root resolution: $CLAUDE_PLUGIN_ROOT is set by the Claude Code harness
# when the hook is loaded from a plugin. Fall back to script location.
# ---------------------------------------------------------------------------
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  plugin_root="$CLAUDE_PLUGIN_ROOT"
else
  plugin_root="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
fi

hooks_dir="$plugin_root/hooks"
hooks_json="$hooks_dir/hooks.json"

# Repo root for .claude/ subdirectory (markers, debug log).
repo_root="$(git -C "$plugin_root" rev-parse --show-toplevel 2>/dev/null || echo "$plugin_root")"
claude_dir="$repo_root/.claude"
debug_log="$claude_dir/kb-debug.log"

_log() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1" >> "$debug_log" 2>/dev/null || true
}

warnings=()

# ---------------------------------------------------------------------------
# 1. jq availability (soft warn — python3 is a functional fallback)
# ---------------------------------------------------------------------------
jq_available=false
if command -v jq >/dev/null 2>&1; then
  jq_available=true
fi

# ---------------------------------------------------------------------------
# 2. Validate hooks.json is well-formed JSON
# ---------------------------------------------------------------------------
if [[ ! -f "$hooks_json" ]]; then
  warnings+=("hooks.json not found at $hooks_json")
else
  json_valid=false
  if $jq_available; then
    jq . "$hooks_json" >/dev/null 2>&1 && json_valid=true
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$hooks_json" >/dev/null 2>&1 && json_valid=true
  fi

  if ! $json_valid; then
    warnings+=("hooks.json failed JSON validation")
  fi
fi

# ---------------------------------------------------------------------------
# 3. Validate every .sh script referenced in hooks.json
# ---------------------------------------------------------------------------
# Extract all "command" values, pull the token ending in .sh, resolve to an
# absolute path by substituting ${CLAUDE_PLUGIN_ROOT} with the detected root.
missing_scripts=()
no_exec_scripts=()
commands=""

if [[ -f "$hooks_json" ]]; then
  if $jq_available; then
    # Walk every "command" value anywhere in the hooks tree.
    commands=$(jq -r '.. | strings | select(endswith(".sh"))' "$hooks_json" 2>/dev/null)
  elif command -v python3 >/dev/null 2>&1; then
    commands=$(HOOKS_JSON="$hooks_json" python3 -c '
import json, os, re, sys

def walk(obj):
    if isinstance(obj, str):
        if obj.endswith(".sh"):
            yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from walk(v)
    elif isinstance(obj, list):
        for item in obj:
            yield from walk(item)

try:
    data = json.load(open(os.environ["HOOKS_JSON"]))
except Exception:
    sys.exit(0)
for s in walk(data):
    print(s)
' 2>/dev/null)
  else
    commands=""
  fi

  while IFS= read -r cmd_value; do
    [[ -z "$cmd_value" ]] && continue
    # Resolve ${CLAUDE_PLUGIN_ROOT}/hooks/foo.sh → absolute path.
    resolved="${cmd_value//\$\{CLAUDE_PLUGIN_ROOT\}/$plugin_root}"
    # Extract the .sh token in case the value is "bash <path>".
    script_path=$(echo "$resolved" | grep -oE '[^ ]+\.sh' | head -1)
    [[ -z "$script_path" ]] && continue

    if [[ ! -f "$script_path" ]]; then
      missing_scripts+=("$(basename "$script_path") missing")
    elif [[ ! -x "$script_path" ]]; then
      no_exec_scripts+=("$(basename "$script_path") missing +x")
    fi
  done <<< "$commands"
fi

# ---------------------------------------------------------------------------
# 4. Detect stale .intent-pending-* markers (> 120 minutes old)
# Pending markers are cleaned each turn by clear-intent-marker.sh.
# A marker surviving into a new session means the previous session exited
# abnormally without the cleanup hook running.
# ---------------------------------------------------------------------------
stale_pending=()
if [[ -d "$claude_dir" ]]; then
  while IFS= read -r marker; do
    stale_pending+=("$(basename "$marker")")
  done < <(find "$claude_dir" -maxdepth 1 -name '.intent-pending-*' -mmin +120 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# 5. Aggregate warnings and build output message
# ---------------------------------------------------------------------------
all_warnings=("${missing_scripts[@]}" "${no_exec_scripts[@]}")

for w in "${stale_pending[@]}"; do
  all_warnings+=("stale intent-pending marker: $w — run clear or let hook clean it")
done

if ! $jq_available; then
  all_warnings+=("jq not installed; python3 fallback active")
fi

# Count registered scripts for the OK summary.
total_scripts=0
if [[ -n "${commands:-}" ]]; then
  while IFS= read -r cmd_value; do
    [[ -z "$cmd_value" ]] && continue
    script_path=$(echo "$cmd_value" | grep -oE '[^ ]+\.sh' | head -1)
    [[ -n "$script_path" ]] && (( total_scripts++ )) || true
  done <<< "$commands"
fi

warn_count=${#all_warnings[@]}

if [[ $warn_count -eq 0 ]]; then
  status_emoji="🔍"
  jq_label="jq available"
  $jq_available || jq_label="python3 fallback"
  summary="${status_emoji} hooks-health: OK — ${total_scripts}/${total_scripts} scripts present, ${jq_label}"
else
  status_emoji="⚠️"
  first_warn="${all_warnings[0]}"
  if [[ $warn_count -eq 1 ]]; then
    summary="${status_emoji} hooks-health: 1 warning — ${first_warn}"
  else
    summary="${status_emoji} hooks-health: ${warn_count} warnings — ${first_warn} (and $((warn_count - 1)) more)"
  fi
fi

_log "hooks-health: ${summary}"

# ---------------------------------------------------------------------------
# 6. Emit output JSON consumed by Claude Code SessionStart protocol
# ---------------------------------------------------------------------------
if $jq_available; then
  json_output=$(jq -n --arg ctx "$summary" '{"hookSpecificOutput": {"additionalContext": $ctx}}' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  json_output=$(HOOKS_HEALTH_CTX="$summary" python3 -c '
import json, os
ctx = os.environ.get("HOOKS_HEALTH_CTX", "")
print(json.dumps({"hookSpecificOutput": {"additionalContext": ctx}}))
' 2>/dev/null)
else
  # Neither tool available; emit a static safe string.
  json_output='{"hookSpecificOutput": {"additionalContext": "hooks-health: jq and python3 unavailable; skipped"}}'
fi

if [[ -n "$json_output" ]]; then
  echo "$json_output"
else
  echo '{"hookSpecificOutput":{"additionalContext":"hooks-health: output assembly failed"}}'
fi
