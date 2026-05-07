#!/usr/bin/env bash
# 11: Promotion via "procedé" preserves the exact content of the pending marker.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root

# Write a pending marker with specific content.
expected_content="sha256:abc123def456"
pending_ts="2026-05-07T00:00:00Z"
pending_path="$PROJECT_ROOT/.claude/.intent-pending-${pending_ts}"
printf '%s' "$expected_content" > "$pending_path"

if [[ ! -f "$pending_path" ]]; then
  echo "SETUP FAIL: pending marker was not written"
  exit 1
fi

# Build stdin JSON with prompt = "procedé" (alternate confirmation phrase).
stdin_json='{"hook_event_name":"UserPromptSubmit","prompt":"procedé","tool_input":{}}'

# Run the hook.
CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
  bash "$REPO_ROOT/hooks/clear-intent-marker.sh" <<< "$stdin_json" > /dev/null

# Assertion 1: a confirmed marker must exist.
shopt -s nullglob
confirmed=("$PROJECT_ROOT/.claude"/.intent-and-routing-confirmed-*)
shopt -u nullglob
if [[ ${#confirmed[@]} -eq 0 ]]; then
  echo "FAIL: 11-promotion-preserves-content — no confirmed marker found after promotion"
  exit 1
fi

# Assertion 2: confirmed marker content must be exactly the expected string.
actual_content=$(cat "${confirmed[0]}")
if [[ "$actual_content" != "$expected_content" ]]; then
  echo "FAIL: 11-promotion-preserves-content — content '$actual_content' != expected '$expected_content'"
  exit 1
fi

echo "PASS: 11-promotion-preserves-content"
exit 0
