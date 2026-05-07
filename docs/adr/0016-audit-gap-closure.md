# ADR-0016: Audit gap closure — hooks, skills, and enforcement (IC-017)

**Date**: 2026-05-07
**Status**: Accepted
**Related**: ADR-0015 (IC-016 two-phase marker, prerequisite), ADR-0014 (v4.5 intent-capture slim)

## Context

After landing IC-016 (two-phase marker), a plugin-wide audit was conducted against three categories:

1. **Unguarded workflow commands** — operations the operator had to perform manually without any automatic health signal or enforcement: hooks health, PR creation preconditions, citation presence after writes.
2. **Skills with incomplete lifecycle** — `batuta-status`, `kb-end-session`, `code-review-and-quality`, `research-first-dev` covered their happy path but lacked explicit step completeness for edge cases (stale data, citation omission).
3. **Workflows without a formal slash command** — slice open/close, vault health, rules import, PR prep existed as operator conventions in `CLAUDE.md` prose but had no skill file to invoke; the operator had to recall and assemble steps manually.

The audit produced a concrete gap list: 3 missing hooks and 6 missing skills, plus 5 existing skills requiring targeted edits.

### Scope of IC-017

| Category | Items |
|---|---|
| New hooks | `hooks-health.sh` (SessionStart), `pre-pr-create-guard.sh` (PreToolUse/Bash), `post-edit-citation-warn.sh` (PostToolUse/Write\|Edit) |
| Edited skills | `batuta-status`, `kb-end-session`, `code-review-and-quality`, `code-graph` (deprecation notice), `research-first-dev` |
| New skills | `hooks-diagnose`, `slice-open`, `slice-close`, `vault-health`, `rules-import`, `pr-prep` |

## Decision

### Hook event assignment

Each new hook targets the Claude Code lifecycle event that is both the earliest possible detection point and the appropriate blocking posture.

**`hooks-health.sh` → SessionStart**
Health checks must run before work begins so the operator is informed of a broken hook chain immediately — not mid-slice when a guard fires unexpectedly and the cause is opaque. SessionStart is the earliest event in a session. The hook is non-blocking (exit 0 always): it reports problems to the operator via `hookSpecificOutput.additionalContext` but does not abort the session. A broken hook should surface as a warning, not as a hard failure that prevents productive work.

**`pre-pr-create-guard.sh` → PreToolUse(Bash)**
`gh pr create` is issued as a Bash command — there is no dedicated Claude Code tool event for GitHub CLI calls. PreToolUse(Bash) is the only available intercept point. Blocking posture is appropriate because PR creation is an external, irreversible action: once a PR is open on GitHub it triggers CI, notifies reviewers, and enters org-level audit logs. A blocking guard that requires `pr-prep` to have run (marker check) prevents half-assembled PRs from entering the shared branch history. The guard inspects the Bash command string for `gh pr create` substring before applying the check.

**`post-edit-citation-warn.sh` → PostToolUse(Write|Edit)**
Citation presence can only be verified after a file has been written — the content does not exist before the write. PreToolUse would require speculative analysis of intent rather than the actual written content. The hook is non-blocking (warning only): the research-first invariant requires that lookups happen *proactively* before writing; the hook is a safety net for forgotten `// Source:` comments, not a replacement for the research step. Blocking here would prevent legitimate writes where research was done in a prior turn and the citation is present but the hook regex does not match the exact format.

### Skill formalization rationale

The 6 new skills convert prose conventions in `CLAUDE.md` into invocable workflows. The threshold for promoting a convention to a skill is: the operator must recall and sequence ≥3 non-trivial steps manually, and the skill adds no duplicate coverage with existing entries. All 6 clear this bar:

- `slice-open` / `slice-close` — branch creation, plan init, session journal open/close are 4–6 steps each, currently embedded as session-handoff prose.
- `pr-prep` — audit chain, changelog, description template: 5 steps, currently in `CLAUDE.md` "Every change → PR" section.
- `vault-health` — stale wikilinks, orphaned entries, missing `related:` frontmatter: 3+ checks, currently undocumented.
- `rules-import` — setup-rules.sh invocation, symlink verification, `.gitignore` addition: 3 steps, currently in `CLAUDE.md` "Plugin rules" section.
- `hooks-diagnose` — detailed hook chain inspection invoked manually when `hooks-health.sh` reports a problem; complements the SessionStart check without duplicating it.

### Discovery-first invariant preserved

All 6 new skills are authored only after running `batuta-skill-authoring` (marker written). The `batuta-skill-authoring` gate is not relaxed for IC-017. Each skill file creation is preceded by its own authoring workflow, including skills.sh catalog search, to confirm no upstream equivalent exists.

## Rejected alternatives

**A. Make `pr-prep` a pre-commit git hook**
Git hooks are per-repository and run outside the Claude Code session. They have no access to session context (which slice is in flight, whether the audit chain ran), cannot call Claude Code tools, and must be installed manually per clone. Claude Code PreToolUse hooks have full session context and fire consistently without per-clone setup. Rejected in favor of the Claude Code hook.

**B. Merge `hooks-health.sh` into `session-start.sh`**
`session-start.sh` already injects vault context, project status, and active plan into session bootstrap. Adding hook-chain health diagnostics to the same script violates single responsibility and makes the script harder to test independently. A failure in health checks would conflate with a failure in vault access. Separate scripts are independently replaceable and testable. Rejected.

**C. Make `post-edit-citation-warn.sh` a blocking gate**
A blocking PostToolUse gate on every Write/Edit that touches an import site would prevent the write from completing when a `// Source:` comment is absent. This reverses causality: research must happen *before* the write (proactive), not be forced at write time (reactive). Blocking would also fire on files that do not import external libraries at all (hooks, shell scripts, markdown). Warning is the correct signal strength — it preserves the file write and prompts the operator to add the citation. Rejected.

**D. Add vault-health as a cron instead of a skill**
A scheduled CronCreate-based agent running weekly could check vault health automatically. Rejected for IC-017 scope: vault health is context-sensitive (the operator may be mid-migration) and an interrupting background agent firing during a focused slice would be disruptive. A manually invoked skill gives the operator control over when the check runs. A cron variant can be added in a future slice once the skill's output format is stable.

## Consequences

### Hook chain changes

- **SessionStart**: now runs 2 scripts — `session-start.sh` (vault/project context) then `hooks-health.sh` (chain diagnostics). Both are non-blocking. Order matters: session context loads first so health output can reference it.
- **PreToolUse(Bash)**: chain order is `pr-merge-guard.sh` → `pr-create-guard.sh` → `pre-edit-intent-gate.sh`. Merge guard runs first (harder violation: unauthorized PR merge), create guard second (softer violation: missing prep), intent gate last (universal).
- **PostToolUse**: now handles 2 matchers — `post-exit-plan-mode.sh` (ExitPlanMode) and `post-edit-citation-warn.sh` (Write|Edit). Both non-blocking.

### Operator surface changes

- `hooks-health.sh` fires silently on healthy installs (no output). Degraded output appears only when a hook is missing or misconfigured.
- `pre-pr-create-guard.sh` adds one operator gate: `pr-prep` must be run (and its marker present) before `gh pr create`. PR prep takes ~2 minutes; the gate prevents the more costly "incomplete PR → re-open" cycle.
- `post-edit-citation-warn.sh` adds a per-write warning when an import site lacks `// Source:`. False positive rate is low: the hook only fires when the written content contains a recognized import pattern and no `Source:` comment.

### Skill authoring overhead

6 new skills each require a `batuta-skill-authoring` workflow run before creation. This is the designed cost of the discovery-first invariant. The overhead is bounded: each authoring workflow takes ~5 minutes; all 6 are run sequentially at the start of IC-017 slice execution before any skill files are written.
