---
name: slice-close
description: Close a feature slice: bundle uncommitted docs, archive plan, run audit chain, open PR, and end session journal.
---

# slice-close

## Overview

Formal exit point for a feature slice. Mirrors `slice-open`. Ensures that all slice artifacts (intent files, session journal, active plan) are properly committed or archived before the PR is opened. Running this skill in order prevents the three common slice-close failures: orphaned intent files, stale plans left in `active/`, and PRs opened with unresolved audit findings.

## When to Use

- Implementation is complete and ready for review
- All tests pass locally
- After running `/code-review-and-quality` or the full audit chain
- NOT when there are still open implementation tasks on the branch

## Process

### Step 1: Pre-flight checks

Abort on the first failure — do not proceed to subsequent steps.

```bash
# Must be on a feat/* branch
git branch --show-current   # expected: feat/<slug>

# No unintended unstaged changes in source files
git status

# No unconfirmed intent pending
ls .claude/.intent-pending-* 2>/dev/null  # must be empty
```

- If the current branch is `main` → abort. Close work must happen on a feature branch.
- If `git status` shows unstaged edits to source files (not `docs/`) → abort. Commit or stash first.
- If any `.intent-pending-*` marker exists → abort. Resolve the in-flight intent before closing.

### Step 2: Bundle uncommitted docs

```bash
# Find unpersisted intent files
git diff --name-only HEAD -- docs/intents/
git ls-files --others --exclude-standard docs/intents/
```

If any intent files are untracked or modified:

```bash
git add docs/intents/
git commit -m "docs: bundle intent files for slice close"
```

If there are no uncommitted intent files, skip this commit.

### Step 3: Archive the plan

Find the active plan for this branch:

```bash
ls docs/plans/active/
# Expected: one file matching YYYY-MM-DD-<slug>.md for the current branch
```

Move it to archive and commit:

```bash
PLAN=$(ls docs/plans/active/*.md)
FILENAME=$(basename "$PLAN")
mv "$PLAN" "docs/plans/archive/$FILENAME"
git add docs/plans/
git commit -m "docs: archive plan for ${FILENAME%.md}"
```

If no plan file is found in `docs/plans/active/` for this branch, note it in the session journal and continue — a missing plan is a smell but not a blocker.

### Step 4: Audit chain

Run the three audit agents sequentially against `git diff main..HEAD`. Each agent reads the diff independently; do not skip any agent.

1. Invoke `test-engineer` subagent
2. Invoke `code-reviewer` subagent
3. Invoke `security-auditor` subagent

If any agent returns **FAIL** (not PASS and not NOT-APPLICABLE):

- Stop. Do not open a PR.
- Report the findings verbatim.
- Resolve each finding, then re-run the failing agent before continuing to Step 5.

NOT-APPLICABLE is a valid result when the diff contains no testable code, no reviewable logic, or no security surface. PASS + NOT-APPLICABLE together allow Step 5 to proceed.

### Step 5: Open PR

```bash
gh pr create \
  --title "feat: <slug>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet 1>
- <bullet 2>

## Test plan
- [ ] <test step 1>
- [ ] <test step 2>

## Artifacts
- Plan archive: docs/plans/archive/<YYYY-MM-DD>-<slug>.md
- Intent files: docs/intents/<relevant IDs>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

The `pre-pr-create-guard.sh` hook runs automatically before `gh pr create` and will block the call if pre-conditions are unmet. If the hook blocks → read its output, fix the reported issue, and re-run.

### Step 6: End session journal

After obtaining the PR number from Step 5:

- Invoke `kb-end-session` skill (or remind the operator to run `/kb-end-session`).
- The `Next` line in the journal must read:

  ```
  Next session entry point: PR #<number> awaiting review
  ```

Do not close the journal before you have the PR number — the `Next` line requires it.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I reviewed the code myself, the audit chain is redundant" | The audit chain runs in three separate agent contexts with a fresh read of the diff. It catches what single-reviewer fatigue misses. Run it every time. |
| "The plan archive step is overhead" | A plan file left in `docs/plans/active/` after the slice closes is an explicit smell documented in CLAUDE.md. Move it every time, without exception. |
| "I'll open the PR and then close the session journal" | Do Step 5 before Step 6. The journal's `Next` line requires the actual PR number. |
| "The intent files can wait for the next session" | Uncommitted intent files are the first thing lost in a compaction. Bundle them before opening the PR. |

## Red Flags

- `docs/plans/active/` has no plan matching the current branch — the slice was never formally opened with `slice-open`.
- `security-auditor` returns FAIL — never open a PR with an unresolved security finding.
- Intent files from this slice were never captured — execution happened without `intent-capture`. Investigate before closing.
- The PR body is missing the plan archive link — reviewers cannot trace the slice's original scope.

## Verification

```bash
# Bundle + archive commits are present
git log --oneline -5

# Plan moved to archive
ls docs/plans/archive/    # file present
ls docs/plans/active/     # file ABSENT

# PR is open
gh pr view --json state,number,title
# Expected: state: OPEN
```
