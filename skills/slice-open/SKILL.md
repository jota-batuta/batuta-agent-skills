---
name: slice-open
description: Open a feature slice: create branch, initialize docs skeleton, write plan template, and make the opening commit.
---

# Slice Open

## Overview

**Formalize the start of a slice.** The CLAUDE.md session-handoff protocol defines slices as the unit of work, but without an opening ceremony the branch, plan, and docs scaffold are left to chance. This skill materializes all three in a single repeatable sequence: branch → plan → docs → commit.

Use this skill for any feature, bugfix, or refactor that will span multiple commits. For one-commit trivial changes, use `git checkout -b` directly.

## When to Use

- Operator describes a new feature, bugfix, or refactor that will span multiple commits
- Starting work on a new IC-NNN ticket or planned slice
- `batuta-project-hygiene mode=feature-init` has already run (or run it first if it has not)
- NOT for trivial one-commit fixes — use `git checkout -b <branch>` directly and skip this skill

## Process

### Step 1 — Name the slice

Derive `<slug>` from the operator description:

- Format: `kebab-case`, ≤ 30 chars
- No ticket prefix — IC-NNN goes in the plan body, not the branch name
- Examples: `payment-webhook`, `retry-backoff`, `auth-token-refresh`

If the operator has not provided enough context to derive a clear slug, ask once:

```
¿Cómo llamamos este slice? (kebab-case, ≤ 30 chars, ej: payment-webhook)
```

### Step 2 — Create branch

```bash
git checkout -b feat/<slug>
```

If the branch already exists locally or remotely, STOP and report to the operator. Do not force-create or reset an existing branch.

### Step 3 — Write the plan file

Create `docs/plans/active/<YYYY-MM-DD>-<slug>.md` using today's date (UTC). Use this template verbatim:

```markdown
# Plan: <Slice title>

## Context
<Why this slice exists — the problem it solves>

## Out of scope
<What is explicitly NOT included>

## Files to create or modify
| Action | Path |
|--------|------|

## Verification
<How to confirm the slice is done>

## Open questions
<Unresolved items before execution>
```

If a plan file with the same slug already exists in `docs/plans/active/`, STOP and report to the operator before overwriting. The file may be a stale artifact from a previous attempt.

### Step 4 — Ensure docs skeleton exists

Silently create the following directories if they are missing. Do not report unless creation was needed:

```bash
mkdir -p docs/plans/active docs/plans/archive docs/sessions docs/intents
```

These directories are required by `/kb-end-session` and intent-capture. Do not touch existing content.

### Step 5 — Opening commit

Stage only the new plan file:

```bash
git add docs/plans/active/<YYYY-MM-DD>-<slug>.md
git commit -m "chore: open slice <slug>"
```

If the plan file already existed before this run (Step 3 found it and stopped), skip the commit. Do not create an empty commit.

## Anti-Rationalizations

| Excuse | Reality |
|--------|---------|
| "I can just `git checkout -b` manually" | The plan file must exist before execution starts. Without it, slice-close cannot verify the plan was archived and the session journal has no handoff anchor. |
| "The plan template is too much overhead for a small slice" | If it is small enough to skip the plan, it is small enough to skip the slice — use a direct commit instead. A slice implies multiple commits. |
| "I'll fill in the plan after I start coding" | Plans filled in after coding describe what was done, not what was decided. The value is the before-state. |

## Red Flags

- `docs/plans/active/` already has a file matching the slug — check before proceeding; do not silently overwrite.
- Branch already exists remotely — another session or collaborator may be working on it.
- Running slice-open without a description clear enough to derive a slug — always resolve the slug before touching git.
- `docs/plans/active/` contains more than one plan — exactly one active plan per branch is the invariant. Surface the collision to the operator.
- Committing with `git add .` or `git add -A` — stage only the plan file.

## Verification

```bash
git branch --show-current          # must show feat/<slug>
ls docs/plans/active/              # must list the new plan file
head -3 docs/plans/active/<YYYY-MM-DD>-<slug>.md  # must show "# Plan:" header
test -d docs/sessions && echo "sessions OK"
test -d docs/intents  && echo "intents OK"
git log -1 --oneline | grep -q "open slice <slug>" && echo "commit OK"
```

If any check fails, the skill did not complete — report the failure before proceeding to implementation.
