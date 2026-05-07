---
name: pr-prep
description: Run pre-PR checklist: verify audit chain ran, intents bundled, plan archived, citations present, and no secrets staged.
---

# pr-prep

## Overview

Interactive pre-PR checklist that runs five checks before `gh pr create`. The `pre-pr-create-guard.sh` hook enforces three of these automatically; this skill covers all five and explains each failure so the operator can fix it before the hook blocks. Stop on the first failure — do not proceed to subsequent checks.

## When to Use

- Before running `gh pr create`
- When `pre-pr-create-guard.sh` blocked the PR and you need to understand what failed
- On any PR that touches sensitive paths (auth, payments, PII)
- As a final review before requesting review from a human

## Process

### Check 1: Audit chain ran

Inspect the branch log to confirm there are commits to review, then verify the audit chain has run against them.

```bash
git log --oneline main..HEAD
```

If commits exist, the audit chain (`test-engineer` → `code-reviewer` → `security-auditor`) must have run this session and returned PASS or NOT-APPLICABLE for each agent.

If not yet run, invoke the three agents now, sequentially:

1. `test-engineer` subagent — reads `git diff main..HEAD`
2. `code-reviewer` subagent — reads `git diff main..HEAD`
3. `security-auditor` subagent — reads `git diff main..HEAD`

If any agent returns FAIL: stop. Resolve findings, then re-run that agent before continuing.

NOT-APPLICABLE is a valid result when the diff contains no testable code, no reviewable logic, or no security surface.

---

### Check 2: Intent files bundled

Find uncommitted intent files that must travel with the slice:

```bash
git diff --name-only HEAD -- docs/intents/
git ls-files --others --exclude-standard docs/intents/
```

If any output appears, stage and commit them now:

```bash
git add docs/intents/
git commit -m "docs: bundle intent files for PR"
```

If both commands produce no output, this check passes — nothing to do.

---

### Check 3: Plan archived

Confirm the active plan for this branch has been moved to archive (expected state after `slice-close`) or is still present in `active/` (expected state mid-slice).

```bash
ls docs/plans/active/
ls docs/plans/archive/
```

If the plan is still in `active/`, move it and commit:

```bash
PLAN=$(ls docs/plans/active/*.md | head -1)
FILENAME=$(basename "$PLAN")
mv "$PLAN" "docs/plans/archive/$FILENAME"
git add docs/plans/
git commit -m "docs: archive plan ${FILENAME%.md}"
```

If the plan is not in `active/` and not in `archive/` (was never created), retroactively create it in `archive/` with what you know of the slice scope, then commit.

---

### Check 4: Source citations present

Detect new imports added in this branch that are missing a `// Source:` or `# Source:` citation comment:

```bash
git diff main..HEAD -- '*.py' '*.ts' '*.js' '*.tsx' '*.jsx' | \
  grep '^+' | \
  grep -E '^(\+import |\+from )' | \
  grep -v '# Source:\|// Source:'
```

If any lines appear, each represents a new import without a citation. For each:

1. Look up the library in Context7 or official docs for the version declared in the manifest.
2. Add a citation comment at the import site:
   - Python: `# Source: <url> (verified YYYY-MM-DD, <lib>@<version>)`
   - TypeScript/JavaScript: `// Source: <url> (verified YYYY-MM-DD, <lib>@<version>)`
3. Stage and commit the citation additions before opening the PR.

Standard library and internal package imports are exempt (see `rules/research-first-citations.md`).

---

### Check 5: No secrets staged

Scan the staged diff for credential patterns:

```bash
git diff --cached | \
  grep -iE '(api[_-]?key|password|secret|token|private[_-]?key)\s*=' | \
  grep '^+' | \
  grep -iv 'test\|mock\|example\|dummy\|placeholder'
```

**If any output appears: STOP. Do not proceed.**

1. Remove the secret from the file immediately.
2. Rotate the credential — assume it is compromised.
3. Check full git history for prior exposure: `git log -p | grep -i <pattern>`.
4. If the secret appears in history, treat the history as compromised and follow the project's incident response procedure.

Only after the secret is fully removed and rotated may you continue.

---

### All checks passed — create the PR

```bash
# Confirm bundle + archive commits are present
git log --oneline -5

# Dry-run to confirm the hook exits 0
gh pr create --dry-run

# Create the PR
gh pr create \
  --title "feat: <slug>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet 1>
- <bullet 2>

## Test plan
- [ ] <step 1>
- [ ] <step 2>

## Artifacts
- Plan archive: docs/plans/archive/<YYYY-MM-DD>-<slug>.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The hook will catch issues anyway" | The hook enforces 3 conditions; this skill enforces 5. Missing citations and secrets are not hook-checked. Find them before the hook runs. |
| "I'll skip the citation check — it's slow" | The grep takes under 2 seconds. Uncited imports accumulate per-import technical debt that compounds with every future reader. |
| "The audit chain is optional for small PRs" | The audit chain is fast for small diffs. It is never optional — three agent contexts catch what single-reviewer fatigue misses. |
| "I'll rotate the secret after I open the PR" | Rotation must happen before any further git operation. The credential is compromised the moment it appears in any diff. |

## Red Flags

- `security-auditor` returns FAIL — never open a PR with an unresolved security finding
- Check 5 finds output — stop, rotate the credential, check full git history for prior exposure
- Plan is absent from both `active/` and `archive/` — retroactively document the slice scope before closing
- Branch has commits but no intent files at all — execution ran without `intent-capture`; investigate before closing

## Verification

After all five checks pass:

```bash
# Bundle and archive commits present (if needed)
git log --oneline -5

# Plan is in archive, not in active
ls docs/plans/archive/   # file present
ls docs/plans/active/    # file absent (or a different branch's plan)

# Hook exits 0 on dry-run
gh pr create --dry-run
```
