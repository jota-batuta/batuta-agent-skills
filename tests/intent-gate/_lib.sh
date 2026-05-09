#!/usr/bin/env bash
# _lib.sh — shared helpers for intent-gate test cases (v4.5).
# Sourced by every NN-*.sh test. Provides setup, marker writers, hook runners.
#
# jq shim: the hooks require jq for JSON parsing. When jq is absent from the
# PATH (CI / WSL without apt access), this lib injects a minimal python3-backed
# shim into a temp bin dir that is prepended to PATH. The shim handles the
# specific jq invocations used by the three intent hooks:
#
#   jq -r '.key // empty'
#   jq -r '.outer.inner // empty'
#   jq -r '.a.b // .a.c // ""'         (alternation, up to 2 alternatives)
#   jq -r '.tool_input.file_path // .tool_input.notebook_path // ""'
#
# REPO_ROOT must be set by run.sh before sourcing this file.

# ---------------------------------------------------------------------------
# jq shim installation (runs once per lib load when jq is absent).
# ---------------------------------------------------------------------------
_install_jq_shim() {
  local shim_dir
  shim_dir="$(mktemp -d)"
  cat > "$shim_dir/jq" <<'PYEOF'
#!/usr/bin/env python3
"""Minimal jq shim for intent-gate tests.

Handles the exact filter patterns used by pre-edit-intent-gate.sh,
pre-task-routing-gate.sh, and clear-intent-marker.sh:

  .key // empty
  .outer.inner // empty
  .a.b // .a.c // ""
"""
import sys, json, re

args = sys.argv[1:]
# strip flags
raw_mode = '-r' in args
args = [a for a in args if not a.startswith('-')]
if not args:
    sys.exit(1)

filter_expr = args[0].strip()

data = sys.stdin.read().strip()
if not data:
    sys.exit(0)

try:
    obj = json.loads(data)
except json.JSONDecodeError:
    sys.exit(1)


def resolve_path(obj, path_str):
    """Resolve a dot-path like 'tool_input.file_path' against obj."""
    keys = path_str.strip().lstrip('.').split('.')
    val = obj
    for k in keys:
        if not k:
            continue
        if isinstance(val, dict):
            val = val.get(k)
        else:
            return None
    return val


def emit(val):
    if val is None or val == "":
        return None
    if isinstance(val, str):
        return val
    if isinstance(val, bool):
        return "true" if val else "false"
    return json.dumps(val)


# Parse alternation:  expr1 // expr2 // fallback
# Each part is either a path ('.a.b') or a quoted literal ('""', 'empty').
parts = [p.strip() for p in filter_expr.split('//')]

for part in parts:
    # empty sentinel — produces no output, move to next
    if part == 'empty':
        continue
    # quoted string literal
    if part.startswith('"') and part.endswith('"'):
        literal = part[1:-1]
        out = emit(literal)
        if out is not None:
            print(out)
        sys.exit(0)
    # path expression
    if part.startswith('.'):
        val = resolve_path(obj, part)
        out = emit(val)
        if out is not None:
            print(out)
            sys.exit(0)
        # val is None/empty — try next alternative
        continue
    # unknown — skip
    continue

# All alternatives exhausted without a non-empty result
sys.exit(0)
PYEOF
  chmod +x "$shim_dir/jq"
  export PATH="$shim_dir:$PATH"
  _JQ_SHIM_DIR="$shim_dir"
  export _JQ_SHIM_DIR
}

if ! command -v jq >/dev/null 2>&1; then
  _install_jq_shim
fi

# ---------------------------------------------------------------------------
# Project root setup.
# ---------------------------------------------------------------------------

# Create a fake project root with a .claude/ directory and an empty git repo.
# Sets PROJECT_ROOT.
setup_project_root() {
  PROJECT_ROOT="$(mktemp -d)"
  mkdir -p "$PROJECT_ROOT/.claude"
  ( cd "$PROJECT_ROOT" && git init -q 2>/dev/null ) || true
  trap 'rm -rf "$PROJECT_ROOT" "${_JQ_SHIM_DIR:-}"' EXIT
  export PROJECT_ROOT
}

# ---------------------------------------------------------------------------
# Marker writers.
# ---------------------------------------------------------------------------

# Write the v4.5 combined intent+routing marker.
write_combined_marker() {
  local iso
  iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '%s' "sha256-placeholder" > "$PROJECT_ROOT/.claude/.intent-and-routing-confirmed-${iso}"
}

# Write the legacy v4.2-v4.4 intent-only marker.
write_legacy_intent_marker() {
  local iso
  iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '%s' "sha256-placeholder" > "$PROJECT_ROOT/.claude/.intent-confirmed-${iso}"
}

# Write the legacy v4.4 routing-only marker.
write_legacy_routing_marker() {
  local iso
  iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '%s' "sha256-placeholder" > "$PROJECT_ROOT/.claude/.routing-confirmed-${iso}"
}

# ---------------------------------------------------------------------------
# Hook runners.
# All runners pass CLAUDE_PROJECT_DIR so hooks resolve the project root to
# PROJECT_ROOT rather than the plugin repo via git rev-parse from CWD.
# ---------------------------------------------------------------------------

# Run pre-edit-intent-gate.sh for a Write tool call against a file path.
# Prints "EXIT=<code> STDERR=<text>" for assertion.
run_edit_gate() {
  local fpath="$1"
  local input
  input=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$fpath")
  local stderr_capture
  stderr_capture=$(mktemp)
  CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
    bash "$REPO_ROOT/hooks/pre-edit-intent-gate.sh" <<< "$input" 2>"$stderr_capture"
  local rc=$?
  local err
  err=$(cat "$stderr_capture")
  rm -f "$stderr_capture"
  printf 'EXIT=%d STDERR=%s' "$rc" "$err"
  return "$rc"
}

# Run pre-edit-intent-gate.sh for a Bash tool call.
# Prints "EXIT=<code> STDERR=<text>" for assertion.
run_bash_gate() {
  local command="$1"
  local input
  input=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$command")
  local stderr_capture
  stderr_capture=$(mktemp)
  CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
    bash "$REPO_ROOT/hooks/pre-edit-intent-gate.sh" <<< "$input" 2>"$stderr_capture"
  local rc=$?
  local err
  err=$(cat "$stderr_capture")
  rm -f "$stderr_capture"
  printf 'EXIT=%d STDERR=%s' "$rc" "$err"
  return "$rc"
}

# Run pre-task-routing-gate.sh against a synthetic Task tool call.
run_routing_gate() {
  local input
  input='{"hook_event_name":"PreToolUse","tool_name":"Task","tool_input":{"prompt":"do something"}}'
  local stderr_capture
  stderr_capture=$(mktemp)
  CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
    bash "$REPO_ROOT/hooks/pre-task-routing-gate.sh" <<< "$input" 2>"$stderr_capture"
  local rc=$?
  local err
  err=$(cat "$stderr_capture")
  rm -f "$stderr_capture"
  printf 'EXIT=%d STDERR=%s' "$rc" "$err"
  return "$rc"
}

# Run clear-intent-marker.sh with a synthetic UserPromptSubmit event.
# Passes CLAUDE_PROJECT_DIR so the hook can locate the marker dir.
run_clear_marker() {
  local input
  input='{"hook_event_name":"UserPromptSubmit","tool_input":{}}'
  CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
    bash "$REPO_ROOT/hooks/clear-intent-marker.sh" <<< "$input" 2>/dev/null
  return 0
}
