---
name: rules-import
description: Import batuta-agent-skills rules into a consumer project via symlinks and register them in the project CLAUDE.md.
---

# Rules Import

## Overview

Projects adopt the `batuta-agent-skills` rules library à la carte. `tools/setup-rules.sh` creates the symlinks, but it requires the operator to know the tool exists, find it, and invoke it correctly. This skill guides rule selection, runs the setup, and verifies the result — leaving the project with working `@.claude/rules/<name>.md` imports and a `.gitignore` entry that prevents per-machine symlinks from polluting shared history.

## When to Use

- Onboarding a new project to the Batuta ecosystem (first rule import)
- Adding a rule from the plugin to an existing project
- After updating to a new plugin version that ships new rules
- When a project's `CLAUDE.md` imports a rule but the symlink is missing (causes `@.claude/rules/<name>.md` to fail to load)

## Process

### Step 1: List available rules

From the plugin root, list every importable rule:

```bash
find "$HOME/.claude/plugins/marketplaces/batuta-agent-skills/rules" \
  -name "*.md" ! -path "*/_meta/*" ! -name "README.md" | sort
```

Display the list with a one-line description extracted from each file's first `## ` heading or opening paragraph.

### Step 2: Select rules

Ask the operator which rules to import. Valid options:

- `--all` — import every rule in `rules/` (except `_meta/` and `README.md`)
- `--rule <category>/<name>` — import one or more specific rules

Common starting set for a new project:

| Rule | Path |
|---|---|
| Code style | `core/code-style.md` |
| Secrets and PII | `core/secrets-and-pii.md` |
| Research-first citations | `core/research-first-citations.md` |
| Intent capture | `core/intent-capture-required.md` |

`intent-capture-required.md` depends on the enforcement hooks. If the project has not installed the Batuta hooks, import the rule but note that enforcement will be passive (documentation only).

### Step 3: Run setup-rules.sh

Run from the consumer project root:

```bash
# Import all rules
bash "$HOME/.claude/plugins/marketplaces/batuta-agent-skills/tools/setup-rules.sh" --all

# Import a specific rule
bash "$HOME/.claude/plugins/marketplaces/batuta-agent-skills/tools/setup-rules.sh" \
  --rule core/code-style.md
```

The script creates symlinks under `<project>/.claude/rules/` pointing to the plugin install path. On Windows without Developer Mode it falls back to copies and prints a warning — note the copy limitation in the session journal.

### Step 4: Register in CLAUDE.md and update .gitignore

For each imported rule verify that `<project>/CLAUDE.md` contains a matching `@` import line. Add missing lines under the `## Engineering invariants` section (create the section if absent):

```markdown
## Engineering invariants (imported from batuta-agent-skills)

@.claude/rules/code-style.md
@.claude/rules/secrets-and-pii.md
@.claude/rules/research-first-citations.md
@.claude/rules/intent-capture-required.md
```

Verify `.gitignore` contains `.claude/rules/`. Symlinks are per-machine and break on clone without the plugin. Add the entry idempotently:

```bash
if ! grep -qxF '.claude/rules/' .gitignore 2>/dev/null; then
  [ -s .gitignore ] && [ -n "$(tail -c1 .gitignore)" ] && printf '\n' >> .gitignore
  printf '.claude/rules/\n' >> .gitignore
fi
```

Final verification:

```bash
ls .claude/rules/                        # symlinks present
grep "\.claude/rules/" .gitignore        # gitignore has the entry
grep "@\.claude/rules/" CLAUDE.md        # CLAUDE.md has the imports
```

## Anti-Rationalizations

| Excuse | Reality |
|---|---|
| "I'll copy the rule files instead of symlinking" | Copies go stale when the plugin updates. Symlinks always reflect the current plugin version. On Windows without Developer Mode the script copies automatically and warns the operator — that is the only sanctioned copy path. |
| "I'll add the @import to CLAUDE.md without running setup-rules.sh" | The file the `@` import references will not exist. Claude Code silently ignores a broken `@` path — the rule is never loaded. |
| "The operator can add .claude/rules/ to .gitignore later" | Later means never. Symlinks committed by accident are painful to remove from history. Add the gitignore entry in the same step as the symlinks. |

## Red Flags

- `.claude/rules/` is committed to git — add to `.gitignore` immediately; symlink targets are machine-specific absolute paths.
- `@.claude/rules/<name>.md` import present in `CLAUDE.md` but no corresponding symlink in `.claude/rules/` — the rule silently does not load.
- `intent-capture-required.md` imported but the Batuta enforcement hooks are not installed — the rule is advisory-only; the operator should decide whether passive documentation is acceptable or hooks should be installed too.
- Absolute symlink targets that encode a user home directory that differs between machines (e.g. `/home/alice/...`) — the script uses the resolved plugin path; verify with `readlink -f .claude/rules/<name>.md`.

## Verification

```bash
# Symlinks resolve to the plugin install path
readlink -f .claude/rules/code-style.md   # should print plugin path

# Imports present in CLAUDE.md
grep "@\.claude/rules/" CLAUDE.md

# .gitignore entry present
grep -xF '.claude/rules/' .gitignore

# No broken symlinks
find .claude/rules -maxdepth 1 -name '*.md' -type l ! -readable \
  && echo "BROKEN SYMLINKS FOUND" || echo "all symlinks readable"
```
