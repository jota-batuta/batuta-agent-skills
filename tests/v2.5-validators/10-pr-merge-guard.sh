#!/usr/bin/env bash
# 10-pr-merge-guard.sh
# Validates the v3.6 pr-merge-guard hook:
#   (a) hooks/pr-merge-guard.sh exists, is executable, has the kill-switch shebang
#   (b) the hook detects 'gh pr merge' with regex (whitespace-tolerant)
#   (c) the hook uses is_bypassed "pr_merge" from lib.sh (operator-side opt-in)
#   (d) the hook fails open on missing jq (does not lock the session)
#   (e) the hook is registered in hooks/hooks.json with matcher 'Bash'
#   (f) the block message references the env var for the operator to discover
# Contract introduced in v3.6.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

case_name="10-pr-merge-guard"
echo "[${case_name}] starting"

HOOK="${REPO_ROOT}/hooks/pr-merge-guard.sh"
HOOKS_JSON="${REPO_ROOT}/hooks/hooks.json"

failed=0

ok()    { echo "  OK   $1"; }
miss()  { echo "  MISS $1"; failed=1; }
drift() { echo "  DRIFT $1"; failed=1; }

# --- (a) hook exists + executable + shebang ---
if [[ ! -f "$HOOK" ]]; then
  miss "hooks/pr-merge-guard.sh missing"
else
  [[ -x "$HOOK" ]] && ok "pr-merge-guard.sh is executable" || miss "pr-merge-guard.sh not executable (chmod +x)"
  head -n1 "$HOOK" | grep -qE '^#!/usr/bin/env bash' \
    && ok "pr-merge-guard.sh has env-bash shebang" \
    || miss "pr-merge-guard.sh missing '#!/usr/bin/env bash' shebang"

  # --- (b) detection regex matches 'gh pr merge' with whitespace tolerance ---
  grep -qE 'gh\[\[:space:\]\]\+pr\[\[:space:\]\]\+merge' "$HOOK" \
    && ok "pr-merge-guard.sh has whitespace-tolerant 'gh pr merge' regex" \
    || miss "pr-merge-guard.sh must match 'gh\\s+pr\\s+merge' (whitespace-tolerant)"

  # --- (c) operator-side opt-in via is_bypassed from lib.sh ---
  # The hook sources lib.sh and calls is_bypassed "pr_merge" instead of
  # checking the env var directly. The bypass env var is configured in
  # plugin-config.json → bypass_env_vars.pr_merge.
  grep -qE 'source.*lib\.sh' "$HOOK" \
    && ok "pr-merge-guard.sh sources lib.sh" \
    || miss "pr-merge-guard.sh must source lib.sh"
  grep -qE 'is_bypassed.*pr_merge' "$HOOK" \
    && ok "pr-merge-guard.sh calls is_bypassed \"pr_merge\"" \
    || miss "pr-merge-guard.sh must call is_bypassed \"pr_merge\""
  # The bypass path must allow (exit 0), not block.
  if grep -B1 -A4 'is_bypassed' "$HOOK" | grep -qE 'exit 0'; then
    ok "is_bypassed path correctly allows (exit 0)"
  else
    miss "is_bypassed path must exit 0 (allow)"
  fi
  # Verify plugin-config.json has the bypass env var configured
  CONFIG="${REPO_ROOT}/hooks/plugin-config.json"
  if [[ -f "$CONFIG" ]] && grep -qE '"pr_merge".*BATUTA_ALLOW_PR_MERGE' "$CONFIG"; then
    ok "plugin-config.json has pr_merge bypass env var configured"
  else
    miss "plugin-config.json must configure bypass_env_vars.pr_merge = BATUTA_ALLOW_PR_MERGE"
  fi

  # --- (d) fail-soft on missing jq ---
  if grep -B1 -A4 'jq.*not installed\|command -v jq' "$HOOK" | grep -qE 'exit 0'; then
    ok "pr-merge-guard.sh fails soft when jq is missing (exit 0)"
  else
    miss "pr-merge-guard.sh must fail soft on missing jq (exit 0, not exit 1)"
  fi

  # --- (f) block message must teach the operator the override mechanism ---
  grep -qE 'BATUTA_ALLOW_PR_MERGE' "$HOOK" \
    && ok "block message references BATUTA_ALLOW_PR_MERGE env var" \
    || miss "block message must reference BATUTA_ALLOW_PR_MERGE for operator discovery"

  # The block path must exit 2. The heredoc starting with 'RULE violated:' runs
  # ~21 lines through the closing 'EOF', then the next line is 'exit 2'. We use
  # -A28 as a safety budget so future edits to the block message (e.g. adding
  # one or two lines) do not silently break this check. If the block message
  # grows past ~26 lines, bump this number — but more importantly, ask whether
  # the message is still actionable for the operator at that length.
  if grep -A28 'RULE violated' "$HOOK" | grep -qE '^exit 2$'; then
    ok "block path exits 2 (denies the tool call)"
  else
    miss "block path must exit 2 to deny the tool call"
  fi
fi

# --- (e) hook is registered in hooks.json with matcher 'Bash' ---
if [[ ! -f "$HOOKS_JSON" ]]; then
  miss "hooks/hooks.json missing"
else
  # Find a PreToolUse entry whose matcher is exactly "Bash" and whose command path
  # references pr-merge-guard.sh. Use jq to be robust against formatting.
  if command -v jq >/dev/null 2>&1; then
    if jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("pr-merge-guard.sh"))' "$HOOKS_JSON" >/dev/null 2>&1; then
      ok "hooks.json registers pr-merge-guard.sh with matcher Bash"
    else
      miss "hooks.json must register pr-merge-guard.sh under matcher 'Bash'"
    fi
  else
    # Fallback grep: look for the matcher and the script name in proximity.
    if grep -A4 '"matcher": "Bash"' "$HOOKS_JSON" | grep -q 'pr-merge-guard.sh'; then
      ok "hooks.json registers pr-merge-guard.sh with matcher Bash (grep fallback)"
    else
      miss "hooks.json must register pr-merge-guard.sh under matcher 'Bash'"
    fi
  fi

  # Existing delegation-guard.sh registration MUST still be present (regression check).
  if grep -q 'delegation-guard.sh' "$HOOKS_JSON"; then
    ok "hooks.json still registers delegation-guard.sh (no regression)"
  else
    miss "hooks.json must continue to register delegation-guard.sh"
  fi
fi

if [[ ${failed} -eq 0 ]]; then
  echo "[${case_name}] PASS"
  exit 0
else
  echo "[${case_name}] FAIL"
  exit 1
fi
