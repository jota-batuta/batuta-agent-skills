#!/usr/bin/env bash
# 12: Write to a new feature CLAUDE.md (subdir) without any marker
#     should be BLOCKED (exit 1 with "RULE violated").
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_batuta_plugin_root

# Point the hook at our sandbox as the project root so it finds (or
# does not find) markers in $PLUGIN_ROOT/.claude/.
export CLAUDE_PROJECT_DIR="$PLUGIN_ROOT"

# Target must NOT exist on disk (creation, not edit) and must be a subdir CLAUDE.md.
target="$PLUGIN_ROOT/src/feature-foo/CLAUDE.md"

out=$(run_hook "pre-write-feature-gate.sh" "$target") || true
echo "12-feature-no-marker-blocks: $out"
if echo "$out" | grep -q 'EXIT=1' && echo "$out" | grep -q 'RULE violated'; then
  echo "PASS: 12-feature-no-marker-blocks"
  exit 0
fi
echo "FAIL: 12-feature-no-marker-blocks"
exit 1
