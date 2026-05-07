#!/usr/bin/env bash
# _lib.sh — shared helpers for hook-additions test suite.
# Sourced by every test-NN-*.sh file. Provides sandbox setup, hook runners,
# and assertion helpers.
#
# REPO_ROOT must be exported by run.sh before any test sources this file.

# ---------------------------------------------------------------------------
# jq shim — mirrors the approach in tests/intent-gate/_lib.sh.
# Hooks use jq for JSON parsing; shim covers the exact filter patterns
# used by pre-pr-create-guard.sh and post-edit-citation-warn.sh.
# ---------------------------------------------------------------------------
_install_jq_shim() {
  local shim_dir
  shim_dir="$(mktemp -d)"
  cat > "$shim_dir/jq" <<'PYEOF'
#!/usr/bin/env python3
"""Minimal jq shim for hook-additions tests.

Handles filter patterns used by hooks under test:
  .tool_input.command // ""
  .tool_name // ""
  .tool_input.file_path // ""
  .hook_event_name // empty
  .agent_id // empty
"""
import sys, json

args = sys.argv[1:]
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


parts = [p.strip() for p in filter_expr.split('//')]

for part in parts:
    if part == 'empty':
        continue
    if part.startswith('"') and part.endswith('"'):
        literal = part[1:-1]
        out = emit(literal)
        if out is not None:
            print(out)
        sys.exit(0)
    if part.startswith('.'):
        val = resolve_path(obj, part)
        out = emit(val)
        if out is not None:
            print(out)
            sys.exit(0)
        continue
    continue

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
# setup_temp_git_repo
# Creates a temporary directory with an initialised git repo and one empty
# commit. Sets SANDBOX_ROOT and registers an EXIT trap for cleanup.
# ---------------------------------------------------------------------------
setup_temp_git_repo() {
  SANDBOX_ROOT="$(mktemp -d)"
  mkdir -p "$SANDBOX_ROOT/.claude"
  ( cd "$SANDBOX_ROOT" \
    && git init -q \
    && git -c user.email="test@test" -c user.name="Test" commit --allow-empty -q -m "init" )
  trap 'rm -rf "$SANDBOX_ROOT" "${_JQ_SHIM_DIR:-}"' EXIT
  export SANDBOX_ROOT
}

# ---------------------------------------------------------------------------
# run_hook <hook_name> <stdin_json>
# Executes hooks/<hook_name> with the given JSON on stdin.
# Captures exit code and stderr. Prints "EXIT=<code> STDERR=<text>".
# Does NOT propagate the exit code — callers inspect the EXIT= field.
# ---------------------------------------------------------------------------
run_hook() {
  local hook_name="$1"
  local stdin_json="$2"
  local stderr_file
  stderr_file="$(mktemp)"
  echo "$stdin_json" \
    | CLAUDE_PROJECT_DIR="$SANDBOX_ROOT" \
      bash "$REPO_ROOT/hooks/$hook_name" 2>"$stderr_file"
  local rc=$?
  local err
  err="$(cat "$stderr_file")"
  rm -f "$stderr_file"
  printf 'EXIT=%d STDERR=%s' "$rc" "$err"
  return 0
}

# ---------------------------------------------------------------------------
# run_hook_env <hook_name> <stdin_json> [VAR=VALUE ...]
# Same as run_hook but prepends extra environment variables to the invocation.
# Extra env vars come after the two required positional args.
# ---------------------------------------------------------------------------
run_hook_env() {
  local hook_name="$1"
  local stdin_json="$2"
  shift 2
  local extra_env=("$@")
  local stderr_file
  stderr_file="$(mktemp)"
  echo "$stdin_json" \
    | CLAUDE_PROJECT_DIR="$SANDBOX_ROOT" \
      env "${extra_env[@]}" \
      bash "$REPO_ROOT/hooks/$hook_name" 2>"$stderr_file"
  local rc=$?
  local err
  err="$(cat "$stderr_file")"
  rm -f "$stderr_file"
  printf 'EXIT=%d STDERR=%s' "$rc" "$err"
  return 0
}

# ---------------------------------------------------------------------------
# assert_exit <expected_code> <actual_output_string> <test_name>
# Checks that EXIT=<expected_code> appears in the output string.
# Prints PASS / FAIL and returns 0 / 1.
# ---------------------------------------------------------------------------
assert_exit() {
  local expected="$1"
  local output="$2"
  local test_name="$3"
  if echo "$output" | grep -q "EXIT=${expected}"; then
    echo "PASS: ${test_name} (exit ${expected})"
    return 0
  fi
  local actual
  actual=$(echo "$output" | grep -oE 'EXIT=[0-9]+' | head -1)
  echo "FAIL: ${test_name} — expected EXIT=${expected}, got ${actual:-unknown}"
  return 1
}

# ---------------------------------------------------------------------------
# assert_output_contains <substring> <actual_output_string> <test_name>
# Checks that the output string contains the substring.
# ---------------------------------------------------------------------------
assert_output_contains() {
  local substring="$1"
  local output="$2"
  local test_name="$3"
  if echo "$output" | grep -qF "$substring"; then
    echo "PASS: ${test_name} (output contains '${substring}')"
    return 0
  fi
  echo "FAIL: ${test_name} — output did not contain '${substring}'"
  echo "  Actual output: ${output}"
  return 1
}

# ---------------------------------------------------------------------------
# assert_output_absent <substring> <actual_output_string> <test_name>
# Checks that the output string does NOT contain the substring.
# ---------------------------------------------------------------------------
assert_output_absent() {
  local substring="$1"
  local output="$2"
  local test_name="$3"
  if echo "$output" | grep -qF "$substring"; then
    echo "FAIL: ${test_name} — output unexpectedly contained '${substring}'"
    echo "  Actual output: ${output}"
    return 1
  fi
  echo "PASS: ${test_name} (output absent '${substring}')"
  return 0
}
