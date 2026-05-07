#!/usr/bin/env bash
# test-03: pre-pr-create-guard.sh — gh pr create command, no uncommitted intents,
# plan exists → exit 0 (allowed).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

TEST_NAME="test-03-pr-create-guard-no-intents-pass"

setup_temp_git_repo

# Create a plan file so Check 2 passes.
mkdir -p "$SANDBOX_ROOT/docs/plans/active"
echo "# Active plan" > "$SANDBOX_ROOT/docs/plans/active/2026-05-07-test-plan.md"
( cd "$SANDBOX_ROOT" \
  && git -c user.email="t@t" -c user.name="T" add docs/plans/active/2026-05-07-test-plan.md \
  && git -c user.email="t@t" -c user.name="T" commit -q -m "add plan" )

# No docs/intents/ directory at all — Check 1 finds nothing uncommitted.
# No stale .intent-pending-* markers.

stdin_json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"},"hook_event_name":"PreToolUse"}'
out="$(run_hook "pre-pr-create-guard.sh" "$stdin_json")"

echo "${TEST_NAME}: $out"
assert_exit 0 "$out" "$TEST_NAME"
