#!/usr/bin/env bash
# 13-research-first-step-1-5.sh
# Validates the research-first-dev SKILL.md structure after v6.0 simplification.
# The skill was reduced from 153 to ~41 lines. Step 1.5, staleness policy,
# dual-cite format, Anti-Rationalizations, Red Flags, and Verification sections
# were removed. The simplified structure retains: 6-layer harness mandate,
# KB lookup order, citation format, and no-prior-art fallback.
# Contract updated in v6.0.

set -uo pipefail

cd "${REPO_ROOT:-$(pwd)}"

fail=0
pass=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  OK   $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL $desc"
    fail=$((fail + 1))
  fi
}

skill="skills/research-first-dev/SKILL.md"

echo "[13-research-first-step-1-5] starting"

check "research-first-dev/SKILL.md exists" "test -f $skill"

# --- 6-Layer Harness Mandate ---
check "6-Layer Harness Mandate section present" "grep -qE '^## 6-Layer Harness Mandate' $skill"

# --- KB Lookup Order ---
check "KB Lookup Order section present" "grep -qE '^## KB Lookup Order' $skill"
check "KB lookup documents L2 > L3 > L1 priority" "grep -qE 'L2.*>.*L3.*>.*L1|L2 curated.*L3.*L1' $skill"
check "KB lookup references vault_root" "grep -qE 'vault_root|VAULT_ROOT' $skill"
check "KB lookup documents staleness policy" "grep -qE 'months.*stale|trustworthy|verification' $skill"

# --- Citation Format ---
check "Citation Format section present" "grep -qE '^## Citation Format' $skill"
check "Citation includes Source: comment format" "grep -qE 'Source:' $skill"
check "Citation includes verified date pattern" "grep -qE 'verified.*YYYY' $skill"

# --- No Prior Art Found ---
check "No Prior Art Found section present" "grep -qE '^## No Prior Art Found' $skill"

if [[ $fail -gt 0 ]]; then
  echo "[13-research-first-step-1-5] FAIL — $fail check(s) failed, $pass passed"
  exit 1
fi

echo "[13-research-first-step-1-5] PASS — $pass checks"
exit 0
