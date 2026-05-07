#!/usr/bin/env bash
# test-06: pre-pr-create-guard.sh — BATUTA_ALLOW_PR_CREATE=1 with missing plan
# → exit 0 (bypass overrides the block).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

TEST_NAME="test-06-pr-create-guard-bypass-pass"

setup_temp_git_repo

# Deliberately no plan and no intents directory — without bypass this would block.

stdin_json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"},"hook_event_name":"PreToolUse"}'
out="$(run_hook_env "pre-pr-create-guard.sh" "$stdin_json" "BATUTA_ALLOW_PR_CREATE=1")"

echo "${TEST_NAME}: $out"
assert_exit 0 "$out" "$TEST_NAME"
