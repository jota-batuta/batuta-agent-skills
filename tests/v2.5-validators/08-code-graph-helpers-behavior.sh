#!/usr/bin/env bash
# 08-code-graph-helpers-behavior.sh
# Originally tested helper functions in tools/setup-code-graph.sh (v3.0).
# The script was intentionally deleted in v5.0 (operator decision:
# codebase-memory-mcp no longer used). This test now verifies the deletion
# is complete — the file must NOT exist.
# Contract updated in v6.0.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SETUP="${REPO_ROOT}/tools/setup-code-graph.sh"

case_name="08-code-graph-helpers-behavior"
echo "[${case_name}] starting"

if [[ ! -f "$SETUP" ]]; then
  echo "  OK   tools/setup-code-graph.sh removed (deletion verified — codebase-memory-mcp no longer used)"
  echo "[${case_name}] PASS"
  exit 0
else
  echo "  MISS tools/setup-code-graph.sh should be absent (operator decision: codebase-memory-mcp removed)"
  echo "[${case_name}] FAIL"
  exit 1
fi
