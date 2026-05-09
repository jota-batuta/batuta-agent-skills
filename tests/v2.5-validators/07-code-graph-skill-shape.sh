#!/usr/bin/env bash
# 07-code-graph-skill-shape.sh
# Validates the code-graph full removal (v5.0 stable baseline).
# Operator decision: codebase-memory-mcp no longer used. All code-graph tooling
# (skills, rules, slash commands, bootstrap scripts) was removed.
# ADR-0007 is preserved for historical record.
# Contract updated in v6.0 to verify deletion is complete.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

case_name="07-code-graph-skill-shape"
echo "[${case_name}] starting"

SKILL="${REPO_ROOT}/skills/code-graph/SKILL.md"
RULE="${REPO_ROOT}/rules/integrations/code-graph-usage.md"
ADR="${REPO_ROOT}/docs/adr/0007-code-graph-dual-engine.md"
SETUP="${REPO_ROOT}/tools/setup-code-graph.sh"
CHECK="${REPO_ROOT}/tools/check-code-graph-engines.sh"
SLASH="${REPO_ROOT}/.claude/commands/code-graph.md"

failed=0

ok()   { echo "  OK   $1"; }
miss() { echo "  MISS $1"; failed=1; }

# --- (a) SKILL.md must be removed (deprecation complete) ---
if [[ ! -f "$SKILL" ]]; then
  ok "skills/code-graph/SKILL.md removed (deprecation complete per ADR-0007/0013)"
else
  miss "skills/code-graph/SKILL.md should be removed (operator decision: codebase-memory-mcp no longer used)"
fi

# --- (b) integrations rule must be removed ---
if [[ ! -f "$RULE" ]]; then
  ok "rules/integrations/code-graph-usage.md removed (deprecation complete)"
else
  miss "rules/integrations/code-graph-usage.md should be removed"
fi

# --- (c) ADR-0007 must still exist (historical record) ---
if [[ -f "$ADR" ]]; then
  ok "docs/adr/0007-code-graph-dual-engine.md exists (historical record preserved)"
else
  miss "docs/adr/0007-code-graph-dual-engine.md missing (must be preserved for history)"
fi

# --- (d) bootstrap scripts must be removed (intentional deletion) ---
if [[ ! -f "$SETUP" ]]; then
  ok "tools/setup-code-graph.sh removed (intentional deletion — codebase-memory-mcp no longer used)"
else
  miss "tools/setup-code-graph.sh should be removed (operator decision: codebase-memory-mcp no longer used)"
fi

if [[ ! -f "$CHECK" ]]; then
  ok "tools/check-code-graph-engines.sh removed (intentional deletion)"
else
  miss "tools/check-code-graph-engines.sh should be removed"
fi

# --- (e) slash command must be removed ---
if [[ ! -f "$SLASH" ]]; then
  ok ".claude/commands/code-graph.md removed (deprecation complete)"
else
  miss ".claude/commands/code-graph.md should be removed"
fi

if [[ ${failed} -eq 0 ]]; then
  echo "[${case_name}] PASS"
  exit 0
else
  echo "[${case_name}] FAIL"
  exit 1
fi
