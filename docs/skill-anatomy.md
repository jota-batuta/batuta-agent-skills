# Skill Anatomy

This document describes the structure and format of skill files (`SKILL.md`) in this plugin. Use it when contributing new skills or understanding existing ones.

> **Skills vs agents.** A **skill** is an invocable workflow (`skills/<name>/SKILL.md`) — instructions the agent follows. An **agent** is a delegation target (`agents/<name>.md`) — a model+role+tools combination the main agent invokes via `Task`. Agents declare `model:` and `tools:` in frontmatter; skills do not. For agent format, see [`skills/batuta-agent-authoring/SKILL.md`](../skills/batuta-agent-authoring/SKILL.md).

## File Location

Every skill lives in its own directory under `skills/`:

```
skills/
  skill-name/
    SKILL.md          # Required: The skill definition
    supporting-file.md # Optional: Reference material loaded on demand
```

## SKILL.md Format

### Frontmatter (Required)

```yaml
---
name: skill-name-with-hyphens
description: Brief statement of what the skill does. Use when [specific trigger conditions].
---
```

**Rules:**
- `name`: Lowercase, hyphen-separated. Must match the directory name.
- `description`: Starts with what the skill does (third person), followed by trigger conditions. Include both *what* and *when*. Maximum 1024 characters.

**Why this matters:** Agents discover skills by reading descriptions. The description is injected into the system prompt, so it must tell the agent both what the skill provides and when to activate it. Do not summarize the workflow — if the description contains process steps, the agent may follow the summary instead of reading the full skill.

### Standard Sections

```markdown
# Skill Title

## Overview
One-two sentences explaining what this skill does and why it matters.

## When to Use
- Bullet list of triggering conditions (symptoms, task types)
- When NOT to use (exclusions)

## [Core Process / The Workflow / Steps]
The main workflow, broken into numbered steps or phases.
Include code examples where they help.
Use flowcharts (ASCII) where decision points exist.

## [Specific Techniques / Patterns]
Detailed guidance for specific scenarios.
Code examples, templates, configuration.

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| Excuse agents use to skip steps | Why the excuse is wrong |

## Red Flags
- Behavioral patterns indicating the skill is being violated
- Things to watch for during review

## Verification
After completing the skill's process, confirm:
- [ ] Checklist of exit criteria
- [ ] Evidence requirements
```

## Section Purposes

### Overview
The "elevator pitch" for the skill. Should answer: What does this skill do, and why should an agent follow it?

### When to Use
Helps agents and humans decide if this skill applies to the current task. Include both positive triggers ("Use when X") and negative exclusions ("NOT for Y").

### Core Process
The heart of the skill. This is the step-by-step workflow the agent follows. Must be specific and actionable — not vague advice.

**Good:** "Run `npm test` and verify all tests pass"
**Bad:** "Make sure the tests work"

### Common Rationalizations
The most distinctive feature of well-crafted skills. These are excuses agents use to skip important steps, paired with rebuttals. They prevent the agent from rationalizing its way out of following the process.

Think of every time an agent has said "I'll add tests later" or "This is simple enough to skip the spec" — those go here with a factual counter-argument.

### Red Flags
Observable signs that the skill is being violated. Useful during code review and self-monitoring.

### Verification
The exit criteria. A checklist the agent uses to confirm the skill's process is complete. Every checkbox should be verifiable with evidence (test output, build result, screenshot, etc.).

## Supporting Files

Create supporting files only when:
- Reference material exceeds 100 lines (keep the main SKILL.md focused)
- Code tools or scripts are needed
- Checklists are long enough to justify separate files

Keep patterns and principles inline when under 50 lines.

## SKILL.eval.yaml

Every skill that has reached production use should have a machine-verifiable acceptance test file at `skills/<name>/SKILL.eval.yaml`. This file defines test cases that verify the skill fires correctly, resists rationalization, and stays silent when not applicable.

### When to Write

Write `SKILL.eval.yaml` when:
- The skill is in the hot path (listed in SKILL_MAP.md Primary Hot Path)
- The skill guards an authoring gate (skill, agent, rule authoring)
- The skill has known rationalization patterns that must be tested

### Schema

~~~yaml
skill: "skill-name"
version: "1.0"
cases:
  - id: "trigger-01"
    description: "Description of what is being tested"
    task: >
      The task text that prompts the agent.
    quality_criteria:
      - "What SUCCESS looks like — verifiable outcome"
    anti_criteria:
      - "What FAILURE looks like — violation to watch for"
~~~

### Fields

| Field | Type | Description |
|---|---|---|
| `skill` | string | Name of the skill being evaluated (must match directory name) |
| `version` | string | Version of the evaluation spec (e.g. "1.0") |
| `cases` | array | List of test cases |
| `cases[].id` | string | Unique case identifier following the prefix conventions below |
| `cases[].description` | string | Human-readable description of the test scenario |
| `cases[].task` | string | Complete, standalone operator prompt that triggers the scenario |
| `cases[].quality_criteria` | string[] | Observable outcomes that define success |
| `cases[].anti_criteria` | string[] | Observable failures that indicate the skill was violated |

### Case ID Conventions

| Prefix | When to use |
|---|---|
| `trigger-XX` | Primary trigger — the skill fires and completes correctly |
| `bypass-XX` | Rationalization attempt — the skill must resist a plausible excuse to skip steps |
| `edge-XX` | Boundary case — the skill correctly identifies when NOT to fire |

### Writing Principles

- Each `task` is a complete, standalone operator prompt — no shared setup between cases.
- `quality_criteria` items describe observable outputs ("Runs `npm test` and reports pass/fail") — not internal state.
- `anti_criteria` items describe observable failures — what a reviewer would see if the skill was violated.
- Minimum: one `trigger-XX` and one `bypass-XX` case per skill. Add `edge-XX` when the skill has a well-defined "when NOT to use" condition.

## Writing Principles

1. **Process over knowledge.** Skills are workflows, not reference docs. Steps, not facts.
2. **Specific over general.** "Run `npm test`" beats "verify the tests".
3. **Evidence over assumption.** Every verification checkbox requires proof.
4. **Anti-rationalization.** Every skip-worthy step needs a counter-argument in the rationalizations table.
5. **Progressive disclosure.** Main SKILL.md is the entry point. Supporting files are loaded only when needed.
6. **Token-conscious.** Every section must justify its inclusion. If removing it wouldn't change agent behavior, remove it.

## Naming Conventions

- Skill directories: `lowercase-hyphen-separated`
- Skill files: `SKILL.md` (always uppercase)
- Supporting files: `lowercase-hyphen-separated.md`
- References: stored in `references/` at the project root, not inside skill directories

## Cross-Skill References

Reference other skills by name:

```markdown
Follow the `test-driven-development` skill for writing tests.
If the build breaks, use the `debugging-and-error-recovery` skill.
```

Don't duplicate content between skills — reference and link instead.
