#!/usr/bin/env bash
# 14: Write to a new feature CLAUDE.md (subdir) with a stale marker (>60 min)
#     should be BLOCKED (exit 1 with "RULE violated").
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_batuta_plugin_root

export CLAUDE_PROJECT_DIR="$PLUGIN_ROOT"

# Write a stale marker using the shared helper (mtime set 2 hours ago).
write_stale_marker "feature"

target="$PLUGIN_ROOT/src/feature-foo/CLAUDE.md"

out=$(run_hook "pre-write-feature-gate.sh" "$target") || true
echo "14-feature-stale-marker-blocks: $out"
if echo "$out" | grep -q 'EXIT=1' && echo "$out" | grep -q 'RULE violated'; then
  echo "PASS: 14-feature-stale-marker-blocks"
  exit 0
fi
echo "FAIL: 14-feature-stale-marker-blocks"
exit 1
