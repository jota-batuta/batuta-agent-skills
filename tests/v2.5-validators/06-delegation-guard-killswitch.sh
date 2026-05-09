#!/usr/bin/env bash
# 06-delegation-guard-killswitch.sh
# Validates that hooks/delegation-guard.sh:
#   (a) sources lib.sh and delegates kill-switch logic to is_kill_switch_path()
#   (b) kill-switch paths are configured in plugin-config.json (not inline)
#   (c) preserves the fail-open (exit 0) branch on empty/unparseable path (v2.7 failure-mode flip)
#   (d) preserves the subagent bypass via is_subagent() from lib.sh
#   (e) does NOT contain old path-whitelist patterns (drift detection)
# Contract introduced in v2.7 (PR #12); refactored to lib.sh in v6.0.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

case_name="06-delegation-guard-killswitch"
echo "[${case_name}] starting"

HOOK="${REPO_ROOT}/hooks/delegation-guard.sh"
CONFIG="${REPO_ROOT}/hooks/plugin-config.json"
failed=0

check_present() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "${pattern}" "${file}"; then
    echo "  OK   $(basename "${file}") — ${label}"
  else
    echo "  MISS $(basename "${file}") — ${label}"
    failed=1
  fi
}

check_absent() {
  local pattern="$1"
  local label="$2"
  if grep -qE "${pattern}" "${HOOK}"; then
    echo "  DRIFT hooks/delegation-guard.sh — ${label} (should NOT be present)"
    failed=1
  else
    echo "  OK   hooks/delegation-guard.sh — ${label} absent (correct)"
  fi
}

# --- (a) Hook sources lib.sh and calls is_kill_switch_path ---
check_present "${HOOK}" 'source.*lib\.sh' "sources lib.sh"
check_present "${HOOK}" 'is_kill_switch_path' "calls is_kill_switch_path()"

# --- (b) Kill-switch paths configured in plugin-config.json ---
check_present "${CONFIG}" 'kill_switch_paths' "plugin-config.json has kill_switch_paths array"
check_present "${CONFIG}" '\.claude/settings\*\.json' "kill-switch: .claude/settings*.json"
check_present "${CONFIG}" '\.claude/hooks/\*' "kill-switch: .claude/hooks/*"
check_present "${CONFIG}" '\.claude/agents/\*' "kill-switch: .claude/agents/*"
check_present "${CONFIG}" '"\.env"' "kill-switch: .env"
check_present "${CONFIG}" 'secrets/\*' "kill-switch: secrets/*"

# Confirmed-marker kill-switch is handled by is_kill_switch_path() reading
# markers.intent_confirmed from config. Verify it is configured.
check_present "${CONFIG}" 'intent_confirmed.*\.intent-and-routing-confirmed-' "kill-switch: intent-confirmed marker configured"

# --- (c) Failure-mode: fail-open (exit 0) on empty/unparseable path (v2.7 flip) ---
check_present "${HOOK}" '\[\[ -z.*file_path' "fail-open: conditional guard on empty file_path present"
# Regression check: the empty-path branch must not exit 1 (would lock the session on parse errors)
check_absent '\[\[ -z.*file_path[^#]*exit 1' "fail-open: empty-path branch must not exit 1 (fail-closed regression)"

# --- (d) Subagent bypass: uses is_subagent from lib.sh ---
check_present "${HOOK}" 'is_subagent' "subagent bypass: calls is_subagent()"

# --- (e) Path-whitelist patterns must NOT be present (drift detection) ---
check_absent 'specs/\*\|specs/' "old path-whitelist: specs/"
check_absent 'docs/\*\|docs/' "old path-whitelist: docs/"
check_absent 'pipeline\.py' "old path-whitelist example: pipeline.py"

if [[ ${failed} -eq 0 ]]; then
  echo "[${case_name}] PASS"
  exit 0
else
  echo "[${case_name}] FAIL"
  exit 1
fi
