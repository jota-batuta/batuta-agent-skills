#!/usr/bin/env bash
# 13: Write to a new feature CLAUDE.md (subdir) with a fresh marker
#     should be ALLOWED (exit 0).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_batuta_plugin_root

export CLAUDE_PROJECT_DIR="$PLUGIN_ROOT"

# Write a fresh marker using the same helper used by other tests.
write_fresh_marker "feature"

target="$PLUGIN_ROOT/src/feature-foo/CLAUDE.md"

out=$(run_hook "pre-write-feature-gate.sh" "$target") || true
echo "13-feature-fresh-marker-allows: $out"
if echo "$out" | grep -q 'EXIT=0'; then
  echo "PASS: 13-feature-fresh-marker-allows"
  exit 0
fi
echo "FAIL: 13-feature-fresh-marker-allows"
exit 1
