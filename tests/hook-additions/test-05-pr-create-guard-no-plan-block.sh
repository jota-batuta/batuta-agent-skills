#!/usr/bin/env bash
# test-05: pre-pr-create-guard.sh — gh pr create with docs/plans/active/ empty
# → exit 1 (blocked because no active plan).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

TEST_NAME="test-05-pr-create-guard-no-plan-block"

setup_temp_git_repo

# Create the plans/active/ dir but leave it empty — no .md files.
mkdir -p "$SANDBOX_ROOT/docs/plans/active"

# No uncommitted intents either — only Check 2 should fire.

stdin_json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"},"hook_event_name":"PreToolUse"}'
out="$(run_hook "pre-pr-create-guard.sh" "$stdin_json")"

echo "${TEST_NAME}: $out"

fail=0
assert_exit 1 "$out" "${TEST_NAME}:exit" || fail=1
assert_output_contains "BLOCKED" "$out" "${TEST_NAME}:stderr-blocked" || fail=1

[[ $fail -eq 0 ]] && exit 0 || exit 1
