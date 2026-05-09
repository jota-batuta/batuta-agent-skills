#!/usr/bin/env bash
# 07: clear-intent-marker.sh must delete the v4.5 combined marker at turn boundary.
#     After the clear hook runs, the edit gate must BLOCK (exit 2).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root
write_combined_marker

# Verify marker exists before clear.
shopt -s nullglob
before=("$PROJECT_ROOT/.claude"/.intent-and-routing-confirmed-*)
shopt -u nullglob
if [[ ${#before[@]} -eq 0 ]]; then
  echo "SETUP FAIL: combined marker was not written"
  exit 1
fi

# Run the clear hook.
run_clear_marker > /dev/null

# Marker must be gone.
shopt -s nullglob
after=("$PROJECT_ROOT/.claude"/.intent-and-routing-confirmed-*)
shopt -u nullglob
if [[ ${#after[@]} -gt 0 ]]; then
  echo "FAIL: 07-clear-deletes-combined-marker — marker still present after clear"
  exit 1
fi

# Confirm edit gate now blocks.
fpath="$PROJECT_ROOT/hooks/some-hook.sh"
out=$(run_edit_gate "$fpath") || true
if echo "$out" | grep -q 'EXIT=2'; then
  echo "PASS: 07-clear-deletes-combined-marker"
  exit 0
fi
echo "FAIL: 07-clear-deletes-combined-marker — gate did not block after marker cleared"
exit 1
