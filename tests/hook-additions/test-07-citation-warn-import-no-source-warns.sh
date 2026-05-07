#!/usr/bin/env bash
# test-07: post-edit-citation-warn.sh — TypeScript file with `import axios from 'axios'`
# and no // Source: comment → exit 0, stderr contains "Source:".
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

TEST_NAME="test-07-citation-warn-import-no-source-warns"

setup_temp_git_repo

# Write the file that the hook will read from disk.
ts_file="$SANDBOX_ROOT/app.ts"
cat > "$ts_file" <<'EOF'
import axios from 'axios'

async function fetchData(url: string) {
  const response = await axios.get(url)
  return response.data
}
EOF

# The hook reads from file_path in the JSON.
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

echo "${TEST_NAME}: EXIT=$rc STDERR=${stderr_content}"

fail=0

# Hook must exit 0 (non-blocking).
if [[ $rc -ne 0 ]]; then
  echo "FAIL: ${TEST_NAME} — hook exited $rc (must always exit 0)"
  fail=1
fi

# Stderr must contain "Source:" as a warning cue.
if echo "$stderr_content" | grep -q "Source:"; then
  echo "PASS: ${TEST_NAME} (stderr contains 'Source:')"
else
  echo "FAIL: ${TEST_NAME} — stderr did not contain 'Source:'"
  fail=1
fi

[[ $fail -eq 0 ]] && exit 0 || exit 1
