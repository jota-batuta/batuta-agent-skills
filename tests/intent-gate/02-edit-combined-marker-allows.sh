#!/usr/bin/env bash
# 02: Write to an implementation file with the v4.5 combined marker must ALLOW (exit 0).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root
write_combined_marker
fpath="$PROJECT_ROOT/hooks/some-hook.sh"
out=$(run_edit_gate "$fpath")
echo "02-edit-combined-marker-allows: $out"
if echo "$out" | grep -q 'EXIT=0'; then
  echo "PASS: 02-edit-combined-marker-allows"
  exit 0
fi
echo "FAIL: 02-edit-combined-marker-allows"
exit 1
