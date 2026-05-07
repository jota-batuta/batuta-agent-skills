#!/usr/bin/env bash
# 09-audit-chain-graph-integration.sh
# Validates the v4.1 removal of Step 0.5 from audit agents.
# (Step 0.5 was non-blocking blast/attack-surface enumeration via code-graph;
#  removed in v4.1 — zero adoption, grep+read covers all use cases for < 10k LOC.)
#   (a) code-reviewer.md does NOT have Step 0.5 (intentionally removed v4.1).
#   (a') security-auditor.md does NOT have Step 0.5 (intentionally removed v4.1).
#   (b) test-engineer.md does NOT have Step 0.5 (scope guard per ADR-0008; unchanged).
#   (c) ADR-0008 exists (historical record of the v3.0 integration contract).
# Contract introduced in v3.0 (ADR-0008); updated in v4.1 to assert removal.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

case_name="09-audit-chain-graph-integration"
echo "[${case_name}] starting"

CR="${REPO_ROOT}/agents/code-reviewer.md"
SA="${REPO_ROOT}/agents/security-auditor.md"
TE="${REPO_ROOT}/agents/test-engineer.md"

failed=0

ok()    { echo "  OK   $1"; }
miss()  { echo "  MISS $1"; failed=1; }
drift() { echo "  DRIFT $1"; failed=1; }

check_present() {
  local file="$1" pattern="$2" label="$3"
  if grep -qE "$pattern" "$file"; then
    ok "$(basename "$file") — $label"
  else
    miss "$(basename "$file") — $label"
  fi
}

check_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -qE "$pattern" "$file"; then
    drift "$(basename "$file") — $label (should NOT be present)"
  else
    ok "$(basename "$file") — $label absent (correct)"
  fi
}

# --- (a) code-reviewer.md must NOT have Step 0.5 (removed in v4.1) ---
if [[ ! -f "$CR" ]]; then
  miss "agents/code-reviewer.md missing"
else
  check_absent "$CR" '## Step 0\.5 — Blast-radius enumeration via code-graph' "Step 0.5 heading (intentionally removed v4.1)"
  check_absent "$CR" 'check-code-graph-engines\.sh'          "check-code-graph-engines.sh call (Step 0.5 removed)"
  check_absent "$CR" 'falling back to diff-only review'      "graceful-degrade string (Step 0.5 removed)"
fi

# --- (a') security-auditor.md must NOT have Step 0.5 (removed in v4.1) ---
if [[ ! -f "$SA" ]]; then
  miss "agents/security-auditor.md missing"
else
  check_absent "$SA" '## Step 0\.5 — Attack-surface enumeration via code-graph' "Step 0.5 heading (intentionally removed v4.1)"
  check_absent "$SA" 'check-code-graph-engines\.sh'          "check-code-graph-engines.sh call (Step 0.5 removed)"
  check_absent "$SA" 'falling back to diff-only audit'       "graceful-degrade string (Step 0.5 removed)"
fi

# --- (b) test-engineer.md must NOT have Step 0.5 (scope guard per ADR-0008) ---
if [[ ! -f "$TE" ]]; then
  miss "agents/test-engineer.md missing"
else
  check_absent "$TE" '## Step 0\.5'                        "Step 0.5 heading (test-engineer scope guard)"
  check_absent "$TE" 'Blast-radius enumeration'            "blast-radius logic"
  check_absent "$TE" 'Attack-surface enumeration'          "attack-surface logic"
fi

# --- (c) ADR-0008 must exist (historical record of v3.0 integration contract) ---
ADR="${REPO_ROOT}/docs/adr/0008-audit-chain-code-graph-integration.md"
[[ -f "$ADR" ]] && ok "docs/adr/0008-audit-chain-code-graph-integration.md exists" || miss "ADR-0008 missing"

if [[ ${failed} -eq 0 ]]; then
  echo "[${case_name}] PASS"
  exit 0
else
  echo "[${case_name}] FAIL"
  exit 1
fi
