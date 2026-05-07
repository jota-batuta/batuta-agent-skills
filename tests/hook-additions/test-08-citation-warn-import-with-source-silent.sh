#!/usr/bin/env bash
# test-08: post-edit-citation-warn.sh — TypeScript file with // Source: comment
# preceding the import → exit 0, stderr does NOT contain "Source:" warning.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

TEST_NAME="test-08-citation-warn-import-with-source-silent"

setup_temp_git_repo

ts_file="$SANDBOX_ROOT/app.ts"
cat > "$ts_file" <<'EOF'
// Source: https://axios-http.com/docs/intro (verified 2026-05-07, axios@1.7.2)
import axios from 'axios'

async function fetchData(url: string) {
  const response = await axios.get(url)
  return response.data
}
EOF

stdin_json=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":""},"hook_event_name":"PostToolUse"}' "$ts_file")

stderr_file="$(mktemp)"
stdout_file="$(mktemp)"
echo "$stdin_json" \
  | CLAUDE_PROJECT_DIR="$SANDBOX_ROOT" \
    bash "$REPO_ROOT/hooks/post-edit-citation-warn.sh" \
    > "$stdout_file" 2>"$stderr_file"
rc=$?
stderr_content="$(cat "$stderr_file")"
rm -f "$stdout_file" "$stderr_file"

echo "${TEST_NAME}: EXIT=$rc STDERR=${stderr_content:-<empty>}"

fail=0

if [[ $rc -ne 0 ]]; then
  echo "FAIL: ${TEST_NAME} — hook exited $rc (must always exit 0)"
  fail=1
fi

# Stderr must NOT contain the "Source:" warning (citation is present → no warning).
# We check for the warning preamble text the hook actually emits.
if echo "$stderr_content" | grep -q "research-first:"; then
  echo "FAIL: ${TEST_NAME} — stderr contained unexpected citation warning"
  echo "  STDERR: $stderr_content"
  fail=1
else
  echo "PASS: ${TEST_NAME} (no citation warning emitted)"
fi

[[ $fail -eq 0 ]] && exit 0 || exit 1
