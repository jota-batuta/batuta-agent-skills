#!/usr/bin/env bash
# test-04: pre-pr-create-guard.sh — gh pr create with an uncommitted docs/intents/ file
# → exit 2 (blocked).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

TEST_NAME="test-04-pr-create-guard-uncommitted-intents-block"

setup_temp_git_repo

# Create a plan so Check 2 passes — we want Check 1 to trigger the block.
mkdir -p "$SANDBOX_ROOT/docs/plans/active"
echo "# Active plan" > "$SANDBOX_ROOT/docs/plans/active/2026-05-07-test-plan.md"
( cd "$SANDBOX_ROOT" \
  && git -c user.email="t@t" -c user.name="T" add docs/plans/active/2026-05-07-test-plan.md \
  && git -c user.email="t@t" -c user.name="T" commit -q -m "add plan" )

# Create an uncommitted intent file (untracked, never git-added).
mkdir -p "$SANDBOX_ROOT/docs/intents"
echo "# intent IC-001" > "$SANDBOX_ROOT/docs/intents/2026-05-07-IC-001-test.md"
# Deliberately do NOT run git add — file is untracked.

stdin_json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"},"hook_event_name":"PreToolUse"}'
out="$(run_hook "pre-pr-create-guard.sh" "$stdin_json")"

echo "${TEST_NAME}: $out"

fail=0
assert_exit 2 "$out" "${TEST_NAME}:exit" || fail=1
assert_output_contains "BLOCKED" "$out" "${TEST_NAME}:stderr-blocked" || fail=1

[[ $fail -eq 0 ]] && exit 0 || exit 1
