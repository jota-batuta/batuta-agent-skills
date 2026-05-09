#!/usr/bin/env bash
# run.sh — hook-additions test suite.
# Runs all test-NN-*.sh scripts in order. Exit 0 on all-pass.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export REPO_ROOT

cd "${REPO_ROOT}"

# Tests 04 removed: pr-create-guard intent-file check was removed in v6.0.
# Tests 07-09 removed: post-edit-citation-warn.sh was deleted in v6.0.
cases=(
  "test-01-hooks-health-pass.sh"
  "test-02-hooks-health-stale-marker-warn.sh"
  "test-03-pr-create-guard-no-intents-pass.sh"
  "test-05-pr-create-guard-no-plan-block.sh"
  "test-06-pr-create-guard-bypass-pass.sh"
)

pass=0
fail=0
fail_names=()

echo "=== hook-additions test suite ==="
echo "Repo root: ${REPO_ROOT}"
echo

for case_file in "${cases[@]}"; do
  case_path="${SCRIPT_DIR}/${case_file}"
  if [[ ! -f "${case_path}" ]]; then
    echo "SKIP: ${case_file} (file not found)"
    fail=$((fail + 1))
    fail_names+=("${case_file} (missing)")
    continue
  fi
  if [[ ! -x "${case_path}" ]]; then
    chmod +x "${case_path}" 2>/dev/null || true
  fi
  if bash "${case_path}"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    fail_names+=("${case_file}")
  fi
  echo
done

echo "=== Summary ==="
echo "Total: ${#cases[@]}"
echo "PASS:  ${pass}"
echo "FAIL:  ${fail}"

if [[ ${fail} -gt 0 ]]; then
  echo
  echo "Failed cases:"
  for name in "${fail_names[@]}"; do
    echo "  - ${name}"
  done
  exit 1
fi

exit 0
