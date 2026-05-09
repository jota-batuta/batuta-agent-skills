---
name: slice-close
description: Close a feature slice: bundle uncommitted docs, archive plan, run audit chain, open PR, and end session journal.
---

# slice-close

Formal exit point for a feature slice. Abort on the first failure at any step.

## Step 1: Pre-flight Checks

- Must be on a `feat/*` branch (not `main`).
- `git status` must show no unstaged edits to source files (docs-only changes are fine).
- No `.claude/.intent-pending-*` markers may exist. Resolve any in-flight intent first.

## Step 2: Bundle Uncommitted Docs

```bash
git diff --name-only HEAD -- docs/intents/
git ls-files --others --exclude-standard docs/intents/
```

If any intent files are untracked or modified:

```bash
git add docs/intents/
git commit -m "docs: bundle intent files for slice close"
```

If none, skip.

## Step 3: Archive the Plan

```bash
PLAN=$(ls docs/plans/active/*.md 2>/dev/null)
if [ -n "$PLAN" ]; then
  FILENAME=$(basename "$PLAN")
  mv "$PLAN" "docs/plans/archive/$FILENAME"
  git add docs/plans/
  git commit -m "docs: archive plan for ${FILENAME%.md}"
fi
```

Missing plan is a smell but not a blocker. Note it in the session journal and continue.

## Step 4: Audit Chain (threshold-based)

Evaluate the diff before invoking gates. Thresholds from `hooks/plugin-config.json` → `audit.*`.

1. Run `git diff --staged --stat` to get LOC added/removed and file count.
2. Run `git diff --staged --name-only` to get file extensions.
3. **Docs-only check:** if ALL changed files have extensions in `audit.docs_only_extensions` (.md, .txt, .yml, .yaml) AND no files are under `hooks/`, `agents/`, `skills/`, `.claude/`, or `rules/` → skip audit chain entirely.
4. **Trivial skip:** if LOC ≤ `audit.skip_threshold_loc` (default 20) AND intent tier is trivial → skip audit chain. Operator reviews directly.
5. **Lite audit:** if LOC ≤ `audit.lite_threshold_loc` (default 50) AND file count ≤ `audit.lite_threshold_files` (default 2) → run only `audit.lite_chain` (default: code-reviewer).
6. **Full audit:** otherwise → run `audit.full_chain` sequentially (default: test-engineer → code-reviewer → security-auditor).

Each agent reads `git diff main..HEAD` independently. If any returns BLOCKED: stop, report findings, reopen with implementer, restart from the first gate in the active chain. APPROVED and NOT-APPLICABLE both allow proceeding.

## Step 5: Open PR

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
- Plan archive: docs/plans/archive/<file>
- Intent files: docs/intents/<relevant IDs>
EOF
)"
```

The `pre-pr-create-guard.sh` hook runs automatically. If it blocks, read its output, fix, and re-run.

## Step 6: End Session Journal

After obtaining the PR number:

- Invoke `kb-end-session`.
- The journal `Next` line must read: `Next session entry point: PR #<number> awaiting review`
- Do not close the journal before you have the PR number.
