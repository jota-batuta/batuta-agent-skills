---
name: using-agent-skills
description: Routes work to the smallest applicable Batuta skill. Use at session start, before concrete work, or when choosing between planning, build, review, delivery, and KB workflows.
---

# Using Agent Skills

## Overview

This is the router. Its job is to pick the smallest workflow that protects the
slice without flooding the context window. Keep the active skill short; detailed
routing examples live in `references/using-agent-skills-longform.md` and the
operational map lives in `docs/SKILL_MAP.md`.

## When to Use

- At session start after reading `CLAUDE.md`, `PROJECT_STATUS.md`, and the
  active plan.
- Before executing any concrete task, command, edit, or delegation.
- When a task changes phase: idea, spec, plan, build, verify, review, ship, KB.
- When the model is about to invent a process instead of invoking one already
  present in this repo.

## Process

1. **Classify the turn.** Read-only questions can be answered directly. Concrete
   action routes first through `intent-capture`.
2. **Pick one primary workflow.** Prefer the narrowest skill that owns the next
   decision, not the whole project.
3. **Layer only necessary support skills.** Examples: `context-engineering`
   before edits, `research-first-dev` before new library/API calls,
   `test-driven-development` before behavior changes, `code-review-and-quality`
   before merge.
4. **Escalate to agents only when useful.** Use base agents for implementation,
   tests, review, and security. Use `agent-architect` only when domain expertise
   is missing from base agents.
5. **Verify and hand off.** Every routed workflow ends with evidence: passing
   checks, explicit NOT-APPLICABLE, or a BLOCKER.

## Routing Table

| Need | Primary skill |
|---|---|
| Confirm concrete work | `intent-capture` |
| Load focused repo context | `context-engineering` |
| Existing solution or current API needed | `research-first-dev` |
| Clarify vague idea | `idea-refine` |
| Write requirements/spec | `spec-driven-development` |
| Break work into slices | `planning-and-task-breakdown` |
| Build a slice | `incremental-implementation` |
| UI or API contract | `frontend-ui-engineering`, `api-and-interface-design` |
| Bug/root cause | `debugging-and-error-recovery` |
| Tests or browser proof | `test-driven-development`, `browser-testing-with-devtools` |
| Review/quality/security/perf | `code-review-and-quality`, `security-and-hardening`, `performance-optimization` |
| Git/PR/release | `git-workflow-and-versioning`, `slice-open`, `slice-close`, `pr-prep` |
| Docs/ADR/KB | `documentation-and-adrs`, `batuta-kb-vault`, `kb-curate`, `kb-backfill` |
| New skill/agent/rule | `batuta-skill-authoring`, `batuta-agent-authoring`, `batuta-rule-authoring` |

## Non-Negotiables

- Do not skip a MUST-trigger skill from `CLAUDE.md`.
- Do not load long reference material unless the short skill points to it and the
  current task needs it.
- Do not invent a new skill when an existing skill covers more than 70% of the
  workflow.
- Do not dispatch a subagent without an approved intent/routing marker in Claude
  Code.

## Verification

- The selected skill name and reason are clear in the working notes or subagent
  prompt.
- Any skipped candidate skill has an explicit reason: read-only, not in scope, or
  delegated to another mandatory skill.
- The final response reports the checks that prove the routed workflow completed.
