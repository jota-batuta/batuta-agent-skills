#!/usr/bin/env bash
# 12: Non-fast-path Bash with no marker present must BLOCK (exit 2).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root
out=$(run_bash_gate "python3 --version") || true
echo "12-bash-no-marker-blocks: $out"
if echo "$out" | grep -q 'EXIT=2' && echo "$out" | grep -q 'RULE violated'; then
  echo "PASS: 12-bash-no-marker-blocks"
  exit 0
fi
echo "FAIL: 12-bash-no-marker-blocks"
exit 1
