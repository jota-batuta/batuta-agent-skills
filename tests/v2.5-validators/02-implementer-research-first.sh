#!/usr/bin/env bash
# 02-implementer-research-first.sh
# Validates that agents/implementer.md requires source-citation comments at every
# import site. Contract introduced in v2.5 (PR #9); agent simplified in v6.0.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

case_name="02-implementer-research-first"
echo "[${case_name}] starting"

failed=0
file="agents/implementer.md"

check() {
  local pattern="$1"
  local label="$2"
  if grep -qE "${pattern}" "${REPO_ROOT}/${file}"; then
    echo "  OK   ${file} — ${label}"
  else
    echo "  MISS ${file} — ${label}"
    failed=1
  fi
}

check "Source:" "mentions Source: citation comments"
check "// Source:|# Source:|-- Source:" "has citation comment format (JS/Python/SQL)"
check "build-log" "references build-log"
check "NEVER write an import without a source-citation" "rule against untraced imports"

if [[ ${failed} -eq 0 ]]; then
  echo "[${case_name}] PASS"
  exit 0
else
  echo "[${case_name}] FAIL"
  exit 1
fi
