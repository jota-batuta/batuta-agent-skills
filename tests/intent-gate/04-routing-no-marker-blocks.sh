#!/usr/bin/env bash
# 04: Task dispatch with no marker present must BLOCK (exit 2, "RULE violated").
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root
out=$(run_routing_gate) || true
echo "04-routing-no-marker-blocks: $out"
if echo "$out" | grep -q 'EXIT=2' && echo "$out" | grep -q 'RULE violated'; then
  echo "PASS: 04-routing-no-marker-blocks"
  exit 0
fi
echo "FAIL: 04-routing-no-marker-blocks"
exit 1
