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
# Marker contract: `<project-root>/.claude/.authoring-marker-feature-<ISO>`
#   - Written by `skills/batuta-project-hygiene` Step 5.5 after the scaffold commit.
#   - Valid for 60 minutes. Older markers are ignored (mtime-based, not filename).
#
# Root resolution: CLAUDE_PROJECT_DIR → git rev-parse --show-toplevel → walk-up .git/
#   Intentionally uses project root, NOT CLAUDE_PLUGIN_ROOT, because this gate
#   fires in consumer projects — not only in the batuta-agent-skills plugin repo.
#
# No repo-scope guard: unlike skill/agent gates, this gate is cross-project by design.
#
# Bypass: BATUTA_FEATURE_INIT_BYPASS=1 (operator-side env var on the launching shell).
#         Cannot be set from inside an agent's tool call.
#
# Output protocol:
#   exit 0 → allow the tool call
#   exit 1 → block the tool call (stderr is shown to the model as the block reason)
#
# Source: https://docs.anthropic.com/en/docs/claude-code/hooks (verified 2026-05-06, Claude Code 2.x)

set -uo pipefail

input=$(cat)

# Fail-soft: jq required to parse stdin JSON. Missing jq → allow with warning.
if ! command -v jq >/dev/null 2>&1; then
  echo "pre-write-feature-gate.sh WARN: jq not installed; gate is permissive. Install with 'winget install jqlang.jq'." >&2
  exit 0
fi

# Subagent bypass: subagents inherit confirmed intent from the main agent.
agent_id=$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null)
if [[ -n "$agent_id" ]]; then
  exit 0
fi

# Extract the target path. Write/Edit/MultiEdit all expose tool_input.file_path.
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Defensive normalization (handles Windows-shaped paths).
file_path="${file_path//\\//}"

# Path-traversal guard: refuse paths where ".." appears as a path segment.
case "$file_path" in
  ../*|*/..|*/../*|..)
    echo "pre-write-feature-gate.sh: path contains '..' as a segment. Refusing." >&2
    exit 1
    ;;
esac

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

# Resolve project root: CLAUDE_PROJECT_DIR → git rev-parse → walk-up .git/
project_root="${CLAUDE_PROJECT_DIR:-}"

if [[ -z "$project_root" ]]; then
  project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi

if [[ -z "$project_root" ]]; then
  # Walk up from the target file's directory looking for .git/
  search_dir="$(dirname "$file_path")"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [[ -d "$search_dir/.git" ]]; then
      project_root="$search_dir"
      break
    fi
    parent="$(dirname "$search_dir")"
    if [[ "$parent" == "$search_dir" ]]; then break; fi
    search_dir="$parent"
  done
fi

if [[ -z "$project_root" ]]; then
  exit 0  # cannot determine project root — fail-soft allow
fi

# Operator-side bypass.
if [[ "${BATUTA_FEATURE_INIT_BYPASS:-0}" == "1" ]]; then
  echo "pre-write-feature-gate.sh: BATUTA_FEATURE_INIT_BYPASS=1 — allowing creation of $file_path" >&2
  mkdir -p "$project_root/.claude" 2>/dev/null
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BYPASS feature-gate file=$file_path" >> "$project_root/.claude/kb-debug.log" 2>/dev/null
  exit 0
fi

# Look for a marker file less than 60 minutes old.
marker_dir="$project_root/.claude"
fresh_marker=""
if [[ -d "$marker_dir" ]]; then
  fresh_marker=$(find "$marker_dir" -maxdepth 1 -name '.authoring-marker-feature-*' -mmin -60 -print -quit 2>/dev/null)
fi

if [[ -n "$fresh_marker" ]]; then
  exit 0
fi

cat >&2 <<EOF
RULE violated (feature-init gate): cannot create feature CLAUDE.md at:
  $file_path

No fresh authoring marker found at $marker_dir/.authoring-marker-feature-* (markers expire after 60 minutes).

Required workflow before creating a feature CLAUDE.md:

  1. Invoke the skill: /skill batuta-project-hygiene  (mode=feature-init <name>)
  2. Complete its workflow end-to-end (Steps 1–5: layout detection, CLAUDE.md, SPEC, commit).
  3. Step 5.5 of the skill writes the marker file. Do not skip it.
  4. Then re-attempt the Write — it will pass.

To bypass for legitimate retrofits (e.g. adding a feature CLAUDE.md retroactively),
restart Claude Code with the operator-side env var:

  BATUTA_FEATURE_INIT_BYPASS=1 claude

Full skill: skills/batuta-project-hygiene/SKILL.md (mode: feature-init)
EOF
exit 1
