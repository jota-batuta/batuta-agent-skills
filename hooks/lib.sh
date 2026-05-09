#!/usr/bin/env bash
# lib.sh — shared functions for all hooks.
# Every hook sources this file to access config-driven values.
# No hook should hard-code marker names, timeouts, paths, or repo identity.
#
# Usage (from any hook):
#   HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
#   source "$HOOK_DIR/lib.sh"

# --- Config loader -----------------------------------------------------------

_PLUGIN_CONFIG=""

_load_config() {
  local config_file="${HOOK_DIR:-$(cd "$(dirname "$0")" && pwd)}/plugin-config.json"
  if [[ -z "$_PLUGIN_CONFIG" ]]; then
    if command -v jq >/dev/null 2>&1 && [[ -f "$config_file" ]]; then
      _PLUGIN_CONFIG=$(cat "$config_file")
    else
      echo "lib.sh WARN: cannot load plugin-config.json (jq missing or file absent)" >&2
      _PLUGIN_CONFIG="{}"
    fi
  fi
}

cfg() {
  _load_config
  echo "$_PLUGIN_CONFIG" | jq -r "$1 // empty" 2>/dev/null
}

cfg_array() {
  _load_config
  echo "$_PLUGIN_CONFIG" | jq -r "$1 // [] | .[]" 2>/dev/null
}

# --- Marker names (from config, never hard-coded) ----------------------------

marker_name() {
  cfg ".markers.$1"
}

# --- Timeout / threshold accessors -------------------------------------------

timeout_val() {
  cfg ".timeouts.$1"
}

# --- Path accessors ----------------------------------------------------------

config_path() {
  cfg ".paths.$1"
}

# --- Bypass check ------------------------------------------------------------

is_bypassed() {
  local key="$1"
  local env_var
  env_var=$(cfg ".bypass_env_vars.$key")
  [[ -n "$env_var" ]] && [[ "${!env_var:-0}" == "1" ]]
}

# --- Repo identity -----------------------------------------------------------

repo_pattern() {
  cfg ".plugin.repo_pattern"
}

# --- Project root resolution -------------------------------------------------

resolve_project_root() {
  local root="${CLAUDE_PROJECT_DIR:-}"
  if [[ -z "$root" ]]; then
    root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  fi
  if [[ -z "$root" ]]; then
    local search_dir="${1:-.}"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      if [[ -d "$search_dir/.git" ]]; then
        root="$search_dir"
        break
      fi
      local parent
      parent="$(dirname "$search_dir")"
      [[ "$parent" == "$search_dir" ]] && break
      search_dir="$parent"
    done
  fi
  echo "$root"
}

# --- Plugin root resolution ---------------------------------------------------

resolve_plugin_root() {
  local root="${CLAUDE_PLUGIN_ROOT:-}"
  if [[ -z "$root" ]]; then
    local search_dir="${1:-.}"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      if [[ -d "$search_dir/.claude-plugin" ]]; then
        root="$search_dir"
        break
      fi
      local parent
      parent="$(dirname "$search_dir")"
      [[ "$parent" == "$search_dir" ]] && break
      search_dir="$parent"
    done
  fi
  echo "$root"
}

# --- Subagent detection -------------------------------------------------------

is_subagent() {
  local input="$1"
  local agent_id
  agent_id=$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null)
  local event_name
  event_name=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
  [[ -n "$agent_id" ]] && [[ "$event_name" == "PreToolUse" ]]
}

# --- Path traversal defense ---------------------------------------------------

has_path_traversal() {
  local path="$1"
  case "$path" in
    ../*|*/..|*/../*|..) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Exempt path check --------------------------------------------------------

is_exempt_path() {
  local file_path="$1"
  local normalized="${file_path//\\//}"

  local pattern
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    case "$normalized" in
      */${pattern}|${pattern}) return 0 ;;
    esac
    # Handle glob patterns with *
    case "$pattern" in
      *\*)
        local prefix="${pattern%%\*}"
        case "$normalized" in
          */"${prefix}"*|"${prefix}"*) return 0 ;;
        esac
        ;;
    esac
  done < <(cfg_array '.exempt_paths')

  return 1
}

# --- Fresh marker check -------------------------------------------------------

find_fresh_marker() {
  local marker_dir="$1"
  local marker_key="$2"
  local ttl_key="${3:-authoring_marker_ttl_minutes}"

  local prefix
  prefix=$(marker_name "$marker_key")
  local ttl
  ttl=$(timeout_val "$ttl_key")

  [[ -z "$prefix" || -z "$ttl" ]] && return 1

  local result
  result=$(find "$marker_dir" -maxdepth 1 -name "${prefix}*" -mmin "-${ttl}" -print -quit 2>/dev/null)
  [[ -n "$result" ]]
}

find_any_marker() {
  local marker_dir="$1"
  local marker_key="$2"

  local prefix
  prefix=$(marker_name "$marker_key")
  [[ -z "$prefix" ]] && return 1

  local result
  result=$(find "$marker_dir" -maxdepth 1 -not -empty -name "${prefix}*" -print -quit 2>/dev/null)
  [[ -n "$result" ]]
}

# --- Kill-switch check --------------------------------------------------------

is_kill_switch_path() {
  local file_path="$1"
  local normalized="${file_path//\\//}"

  local pattern
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    case "$pattern" in
      *\*)
        local prefix="${pattern%%\*}"
        case "$normalized" in
          */"${prefix}"*|"${prefix}"*) return 0 ;;
        esac
        ;;
      *)
        case "$normalized" in
          */"${pattern}"|"${pattern}") return 0 ;;
        esac
        ;;
    esac
  done < <(cfg_array '.kill_switch_paths')

  # Also check confirmed marker paths
  local confirmed_prefix
  confirmed_prefix=$(marker_name "intent_confirmed")
  if [[ -n "$confirmed_prefix" ]]; then
    case "$normalized" in
      */.claude/${confirmed_prefix}*|.claude/${confirmed_prefix}*) return 0 ;;
    esac
  fi

  return 1
}

# --- Logging ------------------------------------------------------------------

_log() {
  local project_root
  project_root=$(resolve_project_root)
  local logfile="${project_root:-.}/.claude/kb-debug.log"
  mkdir -p "$(dirname "$logfile")" 2>/dev/null
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$logfile" 2>/dev/null
}

# --- Read-only Bash fast-path -------------------------------------------------

is_readonly_bash() {
  local cmd="$1"

  local ro_verbs='(ls|eza|tree|stat|file|pwd|which|whoami|id|cat|head|tail|bat|wc|nl|cut|sort|uniq|tr|grep|rg|ripgrep|find|fd|ag|jq|yq|diff|cmp|ps|pgrep|env|echo|printf|date|uname|hostname|dig|nslookup|host|test|true|false|column|xargs|basename|dirname|realpath|readlink|tee)'
  local git_ro='git[[:space:]]+(status|diff|log|show|branch|blame|rev-parse|ls-files|remote|config|describe|reflog|tag|fetch|cat-file|grep)'
  local gh_ro='gh[[:space:]]+(pr|issue|run|workflow|repo|api)[[:space:]]+'

  if echo "$cmd" | grep -qE '[>;|&`]|\$\(' 2>/dev/null; then
    return 1
  fi

  if [[ "$cmd" =~ ^[[:space:]]*${ro_verbs}([[:space:]]|$) ]] || \
     [[ "$cmd" =~ ^[[:space:]]*${git_ro} ]] || \
     [[ "$cmd" =~ ^[[:space:]]*${gh_ro} ]]; then
    return 0
  fi

  return 1
}
