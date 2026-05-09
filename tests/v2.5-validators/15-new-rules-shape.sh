#!/usr/bin/env bash
# 15-new-rules-shape.sh
# Validates structural invariants for the two rules introduced in the
# agent-hardening slice:
#   rules/core/no-hardcoded-magic.md  (simplified to constraints-only in v6.0)
#   rules/core/model-routing.md       (full rule with examples and anti-patterns)
#
# Checks per rule (adapted from batuta-rule-authoring):
#   - File exists
#   - Has valid frontmatter (no name:/description: SKILL.md-only fields)
#   - Has an Inviolable rules heading (numbered rules)
#   - Full rules: ## Anti-patterns present, line count 50-200
#   - Simplified rules: constraints-only (no Anti-patterns required, shorter)
#
# Contract introduced in v3.9; updated in v6.0 for simplified rule format.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

case_name="15-new-rules-shape"
echo "[${case_name}] starting"

failed=0

ok()   { echo "  OK   $1"; }
miss() { echo "  MISS $1"; failed=1; }

# ---------------------------------------------------------------------------
# validate_rule_common <relative-path-from-repo-root>
# Checks shared by all rules: exists, valid frontmatter, has Inviolable rules.
# ---------------------------------------------------------------------------
validate_rule_common() {
  local rel_path="$1"
  local abs_path="${REPO_ROOT}/${rel_path}"

  if [[ ! -f "$abs_path" ]]; then
    miss "${rel_path} — file missing"
    return 1
  fi

  # Inviolable rules heading present
  if grep -qE '^## Inviolable rules' "$abs_path"; then
    ok "${rel_path} — ## Inviolable rules heading present"
  else
    miss "${rel_path} — ## Inviolable rules heading missing"
  fi

  # Frontmatter must NOT contain name: or description: (SKILL.md-only fields)
  local in_frontmatter=0
  local found_skill_key=0
  while IFS= read -r line; do
    if [[ "$in_frontmatter" -eq 0 && "$line" == "---" ]]; then
      in_frontmatter=1
      continue
    fi
    if [[ "$in_frontmatter" -eq 1 && "$line" == "---" ]]; then
      break
    fi
    if [[ "$in_frontmatter" -eq 1 ]]; then
      if echo "$line" | grep -qE "^(name|description):"; then
        found_skill_key=1
        break
      fi
    fi
  done < "$abs_path"

  if [[ "$found_skill_key" -eq 0 ]]; then
    ok "${rel_path} — frontmatter does not contain name:/description: (SKILL.md-only fields)"
  else
    miss "${rel_path} — frontmatter contains name: or description: (forbidden in rule files)"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# validate_full_rule <relative-path>
# Full rule: Anti-patterns required, line count 50-200.
# ---------------------------------------------------------------------------
validate_full_rule() {
  local rel_path="$1"
  local abs_path="${REPO_ROOT}/${rel_path}"

  validate_rule_common "$rel_path" || return

  # Anti-patterns heading present
  if grep -q "^## Anti-patterns" "$abs_path"; then
    ok "${rel_path} — ## Anti-patterns heading present"
  else
    miss "${rel_path} — ## Anti-patterns heading missing (required for full rules)"
  fi

  # Anti-patterns section is non-empty
  local after_heading
  after_heading="$(awk '/^## Anti-patterns/{found=1; next} found && /^## /{exit} found{print}' "$abs_path" \
                   | grep -v '^[[:space:]]*$' || true)"
  if [[ -n "$after_heading" ]]; then
    ok "${rel_path} — ## Anti-patterns section is non-empty"
  else
    miss "${rel_path} — ## Anti-patterns section is empty"
  fi

  # Line count 50-200
  local line_count
  line_count="$(wc -l < "$abs_path")"
  if [[ "$line_count" -ge 50 && "$line_count" -le 200 ]]; then
    ok "${rel_path} — line count ${line_count} within 50-200"
  else
    miss "${rel_path} — line count ${line_count} outside 50-200 range"
  fi
}

# ---------------------------------------------------------------------------
# validate_simplified_rule <relative-path>
# Simplified rule: constraints-only, no Anti-patterns required, no line-count floor.
# ---------------------------------------------------------------------------
validate_simplified_rule() {
  local rel_path="$1"
  local abs_path="${REPO_ROOT}/${rel_path}"

  validate_rule_common "$rel_path" || return

  # Simplified rules have valid frontmatter with title
  if grep -qE '^title: ' "$abs_path"; then
    ok "${rel_path} — frontmatter has title"
  else
    miss "${rel_path} — frontmatter missing title"
  fi
}

# ---------------------------------------------------------------------------
# Run checks
# ---------------------------------------------------------------------------
validate_simplified_rule "rules/core/no-hardcoded-magic.md"
validate_full_rule "rules/core/model-routing.md"

if [[ ${failed} -eq 0 ]]; then
  echo "[${case_name}] PASS"
  exit 0
else
  echo "[${case_name}] FAIL"
  exit 1
fi
