#!/usr/bin/env bash
# pre-write-feature-gate.sh
# PreToolUse hook — enforces the feature-init workflow before creating a
# feature-scoped CLAUDE.md in any subdirectory of a consumer project.
#
# Blocks Write/Edit/MultiEdit on **/CLAUDE.md when:
#   - The file does NOT already exist (creation, not edit), AND
#   - The path is in a subdirectory (not the project root CLAUDE.md), AND
#   - No fresh authoring marker is found.
#
# Marker contract: `<project-root>/.claude/<authoring_feature>-<ISO>`
#   - Written by `skills/batuta-project-hygiene` Step 5.5 after the scaffold commit.
#   - Valid for authoring_marker_ttl_minutes (from config). Older markers are ignored (mtime-based).
#
# Root resolution: CLAUDE_PROJECT_DIR → git rev-parse --show-toplevel → walk-up .git/
#   Intentionally uses project root, NOT CLAUDE_PLUGIN_ROOT, because this gate
#   fires in consumer projects — not only in the batuta-agent-skills plugin repo.
#
# No repo-scope guard: unlike skill/agent gates, this gate is cross-project by design.
#
# Bypass: env var configured in plugin-config.json → bypass_env_vars.feature_init
#
# Output protocol:
#   exit 0 → allow the tool call
#   exit 2 → block the tool call (stderr is shown to the model as the block reason)
#
# Source: https://docs.anthropic.com/en/docs/claude-code/hooks (verified 2026-05-06, Claude Code 2.x)

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib.sh"

input=$(cat)

# Fail-soft: jq required to parse stdin JSON. Missing jq → allow with warning.
if ! command -v jq >/dev/null 2>&1; then
  echo "pre-write-feature-gate.sh WARN: jq not installed; gate is permissive. Install with 'winget install jqlang.jq'." >&2
  exit 0
fi

# Subagent bypass: subagents inherit confirmed intent from the main agent.
if is_subagent "$input"; then
  exit 0
fi

# Extract the target path. Write/Edit/MultiEdit all expose tool_input.file_path.
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Defensive normalization (handles Windows-shaped paths).
file_path="${file_path//\\//}"

# Path-traversal guard via lib.sh.
if has_path_traversal "$file_path"; then
  echo "pre-write-feature-gate.sh: path contains '..' as a segment. Refusing." >&2
  exit 2
fi

# Match scope: only files named CLAUDE.md (any depth).
case "$file_path" in
  */CLAUDE.md|CLAUDE.md)
    : # in scope, continue checks
    ;;
  *)
    exit 0  # not a CLAUDE.md path, out of scope
    ;;
esac

# Root exclusion: the project-level CLAUDE.md at the project root does not need
# a feature-init marker — only feature-scoped CLAUDE.md files in subdirectories do.
# "CLAUDE.md" or "./CLAUDE.md" are both root-level.
case "$file_path" in
  CLAUDE.md|./CLAUDE.md)
    exit 0
    ;;
esac

# If dirname is "." the file is at the project root (already caught above, but
# defensive check for edge cases like "src/../CLAUDE.md" after normalization).
parent_dir=$(dirname "$file_path")
if [[ "$parent_dir" == "." ]]; then
  exit 0
fi

# Edit-vs-create boundary: if the file already exists on disk, it is an Edit
# (allowed without marker). Only new creations are gated.
if [[ -e "$file_path" ]]; then
  exit 0
fi

# Resolve project root via lib.sh.
project_root=$(resolve_project_root "$(dirname "$file_path")")

if [[ -z "$project_root" ]]; then
  exit 0  # cannot determine project root — fail-soft allow
fi

# Operator-side bypass via lib.sh.
if is_bypassed "feature_init"; then
  echo "pre-write-feature-gate.sh: $(cfg ".bypass_env_vars.feature_init")=1 — allowing creation of $file_path" >&2
  mkdir -p "$project_root/.claude" 2>/dev/null
  _log "BYPASS feature-gate file=$file_path"
  exit 0
fi

# Look for a fresh marker via lib.sh (reads TTL from config).
marker_dir="$project_root/.claude"
if [[ -d "$marker_dir" ]] && find_fresh_marker "$marker_dir" "authoring_feature"; then
  exit 0
fi

ttl=$(timeout_val "authoring_marker_ttl_minutes")
cat >&2 <<EOF
RULE violated (feature-init gate): cannot create feature CLAUDE.md at:
  $file_path

No fresh authoring marker found at $marker_dir/$(marker_name "authoring_feature")* (markers expire after ${ttl} minutes).

Required workflow before creating a feature CLAUDE.md:

  1. Invoke the skill: /skill batuta-project-hygiene  (mode=feature-init <name>)
  2. Complete its workflow end-to-end (Steps 1–5: layout detection, CLAUDE.md, SPEC, commit).
  3. Step 5.5 of the skill writes the marker file. Do not skip it.
  4. Then re-attempt the Write — it will pass.

To bypass for legitimate retrofits (e.g. adding a feature CLAUDE.md retroactively),
restart Claude Code with the operator-side env var:

  $(cfg ".bypass_env_vars.feature_init")=1 claude

Full skill: skills/batuta-project-hygiene/SKILL.md (mode: feature-init)
Rule: rules/authoring/feature-init-required.md
EOF
exit 2
