#!/usr/bin/env bash
# 08: "dale" with a pending marker promotes pending → intent-and-routing-confirmed.
#     After promotion the pending marker must be gone and the confirmed marker must
#     contain the same content that was in the pending marker.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root

# Write a pending marker with known content.
pending_content="sha256testcontent"
pending_ts="2026-05-07T00:00:00Z"
pending_path="$PROJECT_ROOT/.claude/.intent-pending-${pending_ts}"
printf '%s' "$pending_content" > "$pending_path"

# Verify the pending marker exists before running the hook.
if [[ ! -f "$pending_path" ]]; then
  echo "SETUP FAIL: pending marker was not written"
  exit 1
fi

# Build stdin JSON with prompt = "dale" (confirmation phrase).
stdin_json='{"hook_event_name":"UserPromptSubmit","prompt":"dale","tool_input":{}}'

# Run the hook.
CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
  bash "$REPO_ROOT/hooks/clear-intent-marker.sh" <<< "$stdin_json" > /dev/null

# Assertion 1: pending marker must be gone.
if [[ -f "$pending_path" ]]; then
  echo "FAIL: 08-pending-dale-promotes-to-confirmed — pending marker still exists after hook"
  exit 1
fi

# Assertion 2: a confirmed marker must exist.
shopt -s nullglob
confirmed=("$PROJECT_ROOT/.claude"/.intent-and-routing-confirmed-*)
shopt -u nullglob
if [[ ${#confirmed[@]} -eq 0 ]]; then
  echo "FAIL: 08-pending-dale-promotes-to-confirmed — no confirmed marker found after promotion"
  exit 1
fi

# Assertion 3: confirmed marker content must match the original pending content.
actual_content=$(cat "${confirmed[0]}")
if [[ "$actual_content" != "$pending_content" ]]; then
  echo "FAIL: 08-pending-dale-promotes-to-confirmed — confirmed content '$actual_content' != expected '$pending_content'"
  exit 1
fi

echo "PASS: 08-pending-dale-promotes-to-confirmed"
exit 0
