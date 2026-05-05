#!/usr/bin/env bash
# 03: Write to an implementation file with a legacy v4.2-v4.4 .intent-confirmed-* marker
#     must ALLOW (exit 0) — legacy markers honored for one release cycle.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

setup_project_root
write_legacy_intent_marker
fpath="$PROJECT_ROOT/hooks/some-hook.sh"
out=$(run_edit_gate "$fpath")
echo "03-edit-legacy-intent-marker-allows: $out"
if echo "$out" | grep -q 'EXIT=0'; then
  echo "PASS: 03-edit-legacy-intent-marker-allows"
  exit 0
fi
echo "FAIL: 03-edit-legacy-intent-marker-allows"
exit 1
