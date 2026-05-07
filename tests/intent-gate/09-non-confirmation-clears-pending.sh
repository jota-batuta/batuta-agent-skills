#!/usr/bin/env bash
# 09: A non-confirmation prompt clears the pending marker without promoting it.
#     No confirmed marker must be written.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root

# Write a pending marker with known content.
pending_ts="2026-05-07T00:00:00Z"
pending_path="$PROJECT_ROOT/.claude/.intent-pending-${pending_ts}"
printf '%s' "sha256testcontent" > "$pending_path"

if [[ ! -f "$pending_path" ]]; then
  echo "SETUP FAIL: pending marker was not written"
  exit 1
fi

# Build stdin JSON with a non-confirmation prompt.
stdin_json='{"hook_event_name":"UserPromptSubmit","prompt":"qué es esto?","tool_input":{}}'

# Run the hook.
CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
  bash "$REPO_ROOT/hooks/clear-intent-marker.sh" <<< "$stdin_json" > /dev/null

# Assertion 1: pending marker must be gone (cleared, not promoted).
if [[ -f "$pending_path" ]]; then
  echo "FAIL: 09-non-confirmation-clears-pending — pending marker still exists after hook"
  exit 1
fi

# Assertion 2: no confirmed marker must exist.
shopt -s nullglob
confirmed=("$PROJECT_ROOT/.claude"/.intent-and-routing-confirmed-*)
shopt -u nullglob
if [[ ${#confirmed[@]} -gt 0 ]]; then
  echo "FAIL: 09-non-confirmation-clears-pending — confirmed marker was created for non-confirmation prompt"
  exit 1
fi

echo "PASS: 09-non-confirmation-clears-pending"
exit 0
