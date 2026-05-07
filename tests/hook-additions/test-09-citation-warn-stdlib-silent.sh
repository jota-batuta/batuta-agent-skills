#!/usr/bin/env bash
# test-09: post-edit-citation-warn.sh — TypeScript file with `import fs from 'fs'`
# (Node stdlib) → exit 0, stderr empty (stdlib imports exempt from citation rule).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

TEST_NAME="test-09-citation-warn-stdlib-silent"

setup_temp_git_repo

ts_file="$SANDBOX_ROOT/app.ts"
cat > "$ts_file" <<'EOF'
import fs from 'fs'
import path from 'path'

const content = fs.readFileSync(path.join(__dirname, 'data.json'), 'utf-8')
export default content
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

# Stderr must NOT contain a citation warning for stdlib modules.
if echo "$stderr_content" | grep -q "research-first:"; then
  echo "FAIL: ${TEST_NAME} — hook warned about stdlib import (should be exempt)"
  echo "  STDERR: $stderr_content"
  fail=1
else
  echo "PASS: ${TEST_NAME} (no warning for stdlib import)"
fi

[[ $fail -eq 0 ]] && exit 0 || exit 1
