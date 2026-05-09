#!/usr/bin/env bash
# Validate the Claude Code plugin contract for both installed-plugin and clone-repo usage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ok() { printf 'OK   %s
' "$1"; }
fail() { printf 'FAIL %s
' "$1" >&2; exit 1; }
need_file() { [[ -f "$1" ]] && ok "$1 exists" || fail "$1 missing"; }
need_dir() { [[ -d "$1" ]] && ok "$1 exists" || fail "$1 missing"; }
json_file() { python3 -m json.tool "$1" >/dev/null && ok "$1 is valid JSON" || fail "$1 invalid JSON"; }

need_file .claude-plugin/plugin.json
need_file hooks/hooks.json
need_file .claude/kb-config.json
need_dir agents
need_dir skills
need_dir rules
need_dir hooks
need_dir .claude/commands
need_dir docs

json_file .claude-plugin/plugin.json
json_file hooks/hooks.json
json_file .claude/kb-config.json

python3 - <<'PYEOF'
from pathlib import Path
import sys

errors = []
for path in sorted(Path('skills').glob('*/SKILL.md')):
    lines = path.read_text().splitlines()
    if len(lines) < 4 or lines[0] != '---':
        errors.append(f'{path}: missing YAML frontmatter')
        continue
    end = lines[1:].index('---') + 1 if '---' in lines[1:] else -1
    fm = '\n'.join(lines[1:end])
    if 'name:' not in fm or 'description:' not in fm:
        errors.append(f'{path}: missing name or description')

for path in sorted(Path('agents').glob('*.md')):
    text = path.read_text()
    if not text.startswith('---'):
        errors.append(f'{path}: missing YAML frontmatter')
    for field in ('name:', 'description:', 'model:'):
        if field not in text.split('---', 2)[1]:
            errors.append(f'{path}: missing {field}')

if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('OK   skill and agent frontmatter valid')
PYEOF

bash tests/v2.5-validators/run.sh
bash tests/intent-gate/run.sh
bash tests/authoring-gate/run.sh
bash tests/hook-additions/run.sh
git diff HEAD --check

echo 'PASS validate-plugin: Claude Code plugin contract is green'
