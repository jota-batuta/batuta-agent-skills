#!/usr/bin/env bash
# 01: Write to an implementation file with no marker present must BLOCK (exit 2).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root
fpath="$PROJECT_ROOT/hooks/some-hook.sh"
out=$(run_edit_gate "$fpath") || true
echo "01-edit-no-marker-blocks: $out"
if echo "$out" | grep -q 'EXIT=2' && echo "$out" | grep -q 'RULE violated'; then
  echo "PASS: 01-edit-no-marker-blocks"
  exit 0
fi
echo "FAIL: 01-edit-no-marker-blocks"
exit 1
