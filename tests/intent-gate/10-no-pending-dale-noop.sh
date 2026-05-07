#!/usr/bin/env bash
# 10: "dale" with no pending marker present is a no-op — no confirmed marker created.
#     Hook must exit 0 (fail-soft).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root

# Verify no pending markers exist in this fresh sandbox.
shopt -s nullglob
pending_before=("$PROJECT_ROOT/.claude"/.intent-pending-*)
shopt -u nullglob
if [[ ${#pending_before[@]} -gt 0 ]]; then
  echo "SETUP FAIL: unexpected pending marker found in clean sandbox"
  exit 1
fi

# Build stdin JSON with prompt = "dale".
stdin_json='{"hook_event_name":"UserPromptSubmit","prompt":"dale","tool_input":{}}'

# Run the hook — must exit 0.
CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
  bash "$REPO_ROOT/hooks/clear-intent-marker.sh" <<< "$stdin_json" > /dev/null
hook_rc=$?

# Assertion 1: hook must exit 0 (fail-soft, never blocks).
if [[ $hook_rc -ne 0 ]]; then
  echo "FAIL: 10-no-pending-dale-noop — hook exited $hook_rc (expected 0)"
  exit 1
fi

# Assertion 2: no confirmed marker must have been created.
shopt -s nullglob
confirmed=("$PROJECT_ROOT/.claude"/.intent-and-routing-confirmed-*)
shopt -u nullglob
if [[ ${#confirmed[@]} -gt 0 ]]; then
  echo "FAIL: 10-no-pending-dale-noop — confirmed marker created despite no pending marker"
  exit 1
fi

echo "PASS: 10-no-pending-dale-noop"
exit 0
