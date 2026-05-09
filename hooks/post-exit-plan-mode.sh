#!/bin/bash
# PostToolUse: ExitPlanMode
# Copies the most recently modified plan from ~/.claude/plans/ to
# docs/plans/active/<YYYY-MM-DD>-<slug>.md so plans persist with the repo
# without requiring a manual /save-plan invocation.
#
# Fail-soft: any error exits 0 so the hook never blocks the session.

set +e
trap 'exit 0' ERR

# Source shared config library
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib.sh"

latest=$(ls -t "${HOME}/.claude/plans/"*.md 2>/dev/null | head -1)
[ -z "$latest" ] && exit 0

# Derive slug: strip date prefix and "plan-" prefix, then restrict to safe filename chars.
slug=$(basename "$latest" .md \
  | sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-//' \
  | sed 's/^plan-//' \
  | tr -cd 'A-Za-z0-9._-')
[ -z "$slug" ] && slug="plan"

# Resolve repo root; skip silently if not in a git repo.
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$repo_root" ] && exit 0

target_dir="${repo_root}/$(config_path "plans_active")"
[ ! -d "$target_dir" ] && exit 0  # batuta-project-hygiene not yet run; skip silently

target="${target_dir}/$(date +%Y-%m-%d)-${slug}.md"
# Overwrite only if the source plan is newer than what's already saved.
if [[ -f "$target" ]] && [[ ! "$latest" -nt "$target" ]]; then
  exit 0
fi

cp "$latest" "$target"
printf '{"priority":"IMPORTANT","message":"Plan auto-saved to docs/plans/active/%s-%s.md"}\n' \
  "$(date +%Y-%m-%d)" "$slug" >&2
