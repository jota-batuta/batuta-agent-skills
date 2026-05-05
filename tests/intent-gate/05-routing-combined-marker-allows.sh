#!/usr/bin/env bash
# 05: Task dispatch with the v4.5 combined .intent-and-routing-confirmed-* marker
#     must ALLOW (exit 0).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root
write_combined_marker
out=$(run_routing_gate)
echo "05-routing-combined-marker-allows: $out"
if echo "$out" | grep -q 'EXIT=0'; then
  echo "PASS: 05-routing-combined-marker-allows"
  exit 0
fi
echo "FAIL: 05-routing-combined-marker-allows"
exit 1
