#!/usr/bin/env bash
# pre-pr-create-guard.sh
# PreToolUse hook — blocks `gh pr create` when the slice is not ready:
#   1. docs/intents/ has uncommitted files (should be bundled in the commit)
#   2. docs/plans/active/ has no .md file (PR without a plan is a naked slice)
#   3. A stale .intent-pending-* marker exists (>60 min old, unresolved intent)
#
# Bypass: BATUTA_ALLOW_PR_CREATE=1 (operator-side env var).
# Subagent bypass: agent_id present in stdin JSON — exit 0.
#
# Output protocol:
#   exit 0 → allow
#   exit 2 → block (stderr shown to the model)
#
# Source: https://docs.claude.com/en/docs/claude-code/hooks (verified 2026-05-07, Claude Code 2.x)

set -uo pipefail

# On unexpected errors: log and block. This is a blocking hook; a configuration
# error should stop the PR, not silently allow it.
handle_error() {
  echo "[pre-pr-create-guard] ERROR: unexpected error at line ${BASH_LINENO[0]}. Blocking gh pr create for safety." >&2
  exit 2
}
trap 'handle_error' ERR

input=$(cat)

# Fail-soft: jq is preferred; fall back to python3 for JSON parsing.
if command -v jq >/dev/null 2>&1; then
  bash_command=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
  event_name=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
  agent_id=$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null)
else
  bash_command=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
  event_name=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))" 2>/dev/null || echo "")
  agent_id=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_id',''))" 2>/dev/null || echo "")
fi

# Subagent bypass: subagents don't create PRs normally, but keep consistent with other hooks.
if [[ "$event_name" == "PreToolUse" && -n "$agent_id" ]]; then
  exit 0
fi

# Only act on `gh pr create` commands.
if ! echo "$bash_command" | grep -qE 'gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
  exit 0
fi

# Operator-side bypass.
if [[ "${BATUTA_ALLOW_PR_CREATE:-0}" == "1" ]]; then
  mkdir -p "${CLAUDE_PROJECT_DIR:-/tmp}/.claude" 2>/dev/null || true
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BYPASS pre-pr-create-guard BATUTA_ALLOW_PR_CREATE=1" \
    >> "${CLAUDE_PROJECT_DIR:-/tmp}/.claude/kb-debug.log" 2>/dev/null || true
  exit 0
fi

# Resolve project root: env var → git rev-parse from CWD.
project_root="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$project_root" ]]; then
  project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi

if [[ -z "$project_root" ]]; then
  # Cannot resolve root — fail-soft allow. Without a root we can't inspect docs/.
  echo "[pre-pr-create-guard] WARN: could not resolve project root; skipping checks." >&2
  exit 0
fi

# ── Check 1: uncommitted intent files ────────────────────────────────────────
uncommitted=$(
  { git -C "$project_root" diff --name-only HEAD -- docs/intents/ 2>/dev/null; \
    git -C "$project_root" ls-files --others --exclude-standard docs/intents/ 2>/dev/null; } \
  | grep -v '^$' || true
)

if [[ -n "$uncommitted" ]]; then
  echo "[pre-pr-create-guard] BLOCKED: Intent files not bundled: bundle docs/intents/ in a commit before opening PR, or use BATUTA_ALLOW_PR_CREATE=1" >&2
  exit 2
fi

# ── Check 2: active plan exists ───────────────────────────────────────────────
plan_count=$(find "$project_root/docs/plans/active" -name "*.md" 2>/dev/null | wc -l)

if [[ "$plan_count" -eq 0 ]]; then
  echo "[pre-pr-create-guard] BLOCKED: No active plan found in docs/plans/active/. Open a PR without a plan only with BATUTA_ALLOW_PR_CREATE=1" >&2
  exit 2
fi

# ── Check 3: no stale intent-pending marker (>60 min) ────────────────────────
stale_pending=$(find "$project_root/.claude" -name ".intent-pending-*" -mmin +60 2>/dev/null | grep -v '^$' || true)

if [[ -n "$stale_pending" ]]; then
  echo "[pre-pr-create-guard] BLOCKED: Stale intent-pending marker — resolve intent before creating PR. Bypass: BATUTA_ALLOW_PR_CREATE=1" >&2
  exit 2
fi

exit 0
