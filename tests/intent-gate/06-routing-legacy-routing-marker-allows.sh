#!/usr/bin/env bash
# 06: Task dispatch with a legacy v4.4 .routing-confirmed-* marker must ALLOW (exit 0)
#     — legacy markers honored for one release cycle.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root
write_legacy_routing_marker
out=$(run_routing_gate)
echo "06-routing-legacy-routing-marker-allows: $out"
if echo "$out" | grep -q 'EXIT=0'; then
  echo "PASS: 06-routing-legacy-routing-marker-allows"
  exit 0
fi
echo "FAIL: 06-routing-legacy-routing-marker-allows"
exit 1
