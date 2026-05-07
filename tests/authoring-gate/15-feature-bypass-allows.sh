#!/usr/bin/env bash
# 15: Write to a new feature CLAUDE.md (subdir) with BATUTA_FEATURE_INIT_BYPASS=1
#     and no marker — should be ALLOWED (exit 0).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_batuta_plugin_root

export CLAUDE_PROJECT_DIR="$PLUGIN_ROOT"
# No marker written intentionally.

target="$PLUGIN_ROOT/src/feature-foo/CLAUDE.md"

out=$(BATUTA_FEATURE_INIT_BYPASS=1 run_hook "pre-write-feature-gate.sh" "$target") || true
echo "15-feature-bypass-allows: $out"
if echo "$out" | grep -q 'EXIT=0'; then
  echo "PASS: 15-feature-bypass-allows"
  exit 0
fi
echo "FAIL: 15-feature-bypass-allows"
exit 1
