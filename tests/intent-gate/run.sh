#!/usr/bin/env bash
# run.sh — intent-gate test suite (v6.0).
# Validates pre-edit-intent-gate.sh against the marker contract.
# Tests 04-06 (pre-task-routing-gate.sh) and 07-11 (clear-intent-marker.sh) removed in v6.0
# because those hooks were deleted. See CHANGELOG.md [6.0.0].
# Exit 0 on all-pass.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export REPO_ROOT

cd "${REPO_ROOT}"

cases=(
  "01-edit-no-marker-blocks.sh"
  "02-edit-combined-marker-allows.sh"
  "03-edit-legacy-intent-marker-allows.sh"
  "12-bash-no-marker-blocks.sh"
)

pass=0
fail=0
fail_names=()

echo "=== intent-gate test suite (v4.5) ==="
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
