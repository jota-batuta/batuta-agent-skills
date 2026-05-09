#!/usr/bin/env bash
# 01-engines-state-roundtrip.sh
# E2E sanity: verify code-graph tools were intentionally removed in v6.0.
# The operator decided to delete codebase-memory-mcp support. This test
# confirms the scripts are absent (not accidentally re-introduced).
#
# Does NOT require the claude CLI. Always runnable.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
SETUP="${REPO_ROOT}/tools/setup-code-graph.sh"
CHECK="${REPO_ROOT}/tools/check-code-graph-engines.sh"

if [[ -f "$SETUP" ]]; then
  echo "  FAIL tools/setup-code-graph.sh should not exist (deleted in v6.0)"
  exit 1
fi
echo "  OK   tools/setup-code-graph.sh absent (deleted in v6.0)"

if [[ -f "$CHECK" ]]; then
  echo "  FAIL tools/check-code-graph-engines.sh should not exist (deleted in v6.0)"
  exit 1
fi
echo "  OK   tools/check-code-graph-engines.sh absent (deleted in v6.0)"

echo "  PASS scenario 01"
exit 0
