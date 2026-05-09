#!/usr/bin/env bash
# test-02: hooks-health.sh with a stale .intent-pending-* marker (>120 min)
# → exit 0 (fail-soft), output contains "stale".
#
# Strategy: build a self-contained fake plugin root that is its own git repo.
# The hook resolves claude_dir via:
#   repo_root="$(git -C "$plugin_root" rev-parse --show-toplevel)"
#   claude_dir="$repo_root/.claude"
# So the stale marker must live in <fake_plugin_root>/.claude/.
#
# Note: _lib.sh may install a minimal jq shim that does NOT support `jq -n --arg`.
# hooks-health.sh uses `jq -n --arg` for its JSON output assembly. We capture the
# original PATH before sourcing _lib.sh and restore it for the hook invocation so
# the real python3 fallback path inside the hook is used instead of the shim.
set -uo pipefail

_ORIGINAL_PATH="$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

TEST_NAME="test-02-hooks-health-stale-marker-warn"

# Build a minimal fake plugin that is its own git repo.
fake_plugin="$(mktemp -d)"
trap 'rm -rf "$fake_plugin" "${_JQ_SHIM_DIR:-}"' EXIT

mkdir -p "$fake_plugin/hooks" "$fake_plugin/.claude"

# Initialise as a git repo so git rev-parse resolves cleanly.
( cd "$fake_plugin" \
  && git init -q \
  && git -c user.email="t@t" -c user.name="T" commit --allow-empty -q -m "init" )

# Minimal hooks.json referencing only hooks-health.sh (avoids "missing script" warnings
# from Steps 2/3 which would add noise; we only want to test Step 4).
cat > "$fake_plugin/hooks/hooks.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/hooks-health.sh"}
    ]
  }
}
JSON

# Copy hooks-health.sh + lib.sh + plugin-config.json so the fake plugin is self-contained.
cp "$REPO_ROOT/hooks/hooks-health.sh" "$fake_plugin/hooks/hooks-health.sh"
cp "$REPO_ROOT/hooks/lib.sh" "$fake_plugin/hooks/lib.sh"
cp "$REPO_ROOT/hooks/plugin-config.json" "$fake_plugin/hooks/plugin-config.json"
chmod +x "$fake_plugin/hooks/hooks-health.sh" "$fake_plugin/hooks/lib.sh"

# Drop a stale .intent-pending-* marker in the fake plugin's .claude/ dir.
# The hook does: find "$claude_dir" -name '.intent-pending-*' -mmin +120
stale_marker="$fake_plugin/.claude/.intent-pending-stale-test"
touch "$stale_marker"
touch -d "130 minutes ago" "$stale_marker" 2>/dev/null \
  || touch -t "202601010000.00" "$stale_marker"

stdout_file="$(mktemp)"
stderr_file="$(mktemp)"
# Invoke with the original PATH so the hook's python3 fallback for `jq -n --arg`
# is not shadowed by the minimal jq shim installed by _lib.sh.
CLAUDE_PLUGIN_ROOT="$fake_plugin" PATH="$_ORIGINAL_PATH" \
  bash "$fake_plugin/hooks/hooks-health.sh" \
  > "$stdout_file" 2>"$stderr_file"
rc=$?
stdout_content="$(cat "$stdout_file")"
stderr_content="$(cat "$stderr_file")"
rm -f "$stdout_file" "$stderr_file"

echo "${TEST_NAME}: EXIT=$rc STDOUT=${stdout_content} STDERR=${stderr_content:-<empty>}"

# Hook must always exit 0 (fail-soft contract).
if [[ $rc -ne 0 ]]; then
  echo "FAIL: ${TEST_NAME} — hook exited $rc (must always exit 0)"
  exit 1
fi

# Output must contain "stale" (the warning about the pending marker).
if echo "${stdout_content}${stderr_content}" | grep -qi "stale"; then
  echo "PASS: ${TEST_NAME}"
  exit 0
fi

echo "FAIL: ${TEST_NAME} — output did not contain 'stale'"
exit 1
