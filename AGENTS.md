# AGENTS.md

This file is the cross-tool entry point for AI coding agents working in this repository. It is the standard companion to tool-specific files (`CLAUDE.md`, `.cursor/rules/`, `.aider.conf.yml`, `GEMINI.md`, etc.) and is read natively by OpenAI Codex CLI, Cursor (as complement), Aider (via `read:`), Gemini CLI, OpenCode, and as fallback by Claude Code.

## Repository Overview

`batuta-agent-skills` is a Claude Code plugin that ships:

- **Nine agents** with explicit `model:` declarations (5 base + `agent-architect` meta-agent + 3 KB pipeline agents)
- A **plugin-level PreToolUse hook** that enforces Rule #0 (the main agent never edits source code; everything goes through delegation)
- A **sequential audit chain** (`test-engineer` → `code-reviewer` → `security-auditor`) with literal `AUDIT RESULT: APPROVED|BLOCKED` contract
- A **project-wide doc graph** (`docs/PRD.md`, `docs/SPEC.md`, `docs/adr/`, `docs/plans/`, `docs/sessions/`)
- **34 skills** (engineering lifecycle + Batuta-specific KB and authoring skills)
- **OpenCode interop** (`.opencode/skills` symlink, `.opencode/agents/` and `.opencode/commands/` with frontmatter rewritten for opencode, `opencode.json` template, `.opencode/AGENTS.md.template` strict contract — see [`docs/opencode-setup.md`](docs/opencode-setup.md))

## Rule #0 — delegation-only main agent (Claude Code-specific runtime)

**The main agent NEVER edits source code directly.** All implementation, testing, and audit work is delegated via the `Task` tool to subagents whose `model:` field is declared explicitly. The audit chain runs sequentially, blocking, before any task closes. This is enforced at runtime in Claude Code by the PreToolUse hook in `hooks/delegation-guard.sh`.

The full contract lives in [`docs/DELEGATION-RULE.md`](docs/DELEGATION-RULE.md). The Haiku/Sonnet/Opus calibration table for choosing which agent to delegate to lives in [`docs/DELEGATION-RULE-SPECIALISTS.md`](docs/DELEGATION-RULE-SPECIALISTS.md).

## Rule #1 — intent-capture before any execution (v4.5)

**You MUST NEVER execute work — `Edit`, `Write`, `Bash`, or `Task` — before capturing a confirmed intent from the operator.** Acting on the first ambiguous bullet produces rework. The protocol is tool-portable; only the runtime enforcement mechanism (marker files + hooks) is Claude-Code-specific.

Full spec: [`rules/core/intent-capture-required.md`](rules/core/intent-capture-required.md). Skill: [`skills/intent-capture/SKILL.md`](skills/intent-capture/SKILL.md). ADR: [`docs/adr/0014-v4.5-intent-capture-slim.md`](docs/adr/0014-v4.5-intent-capture-slim.md).

### The protocol (tool-portable, every tool MUST self-enforce)

1. **Detect** — is this an action request, a continuation of an in-progress intent, or a read-only question? Read-only → answer directly, NEVER grill.
2. **Tier assignment** — assign `tier: "trivial"` IFF ALL FIVE conditions hold:
   - ≤3 files touched
   - ≤20 LOC changed total
   - NO new control flow (no new `if` / `for` / `while` / `try` / `async`)
   - NO new external dependency
   - Category in: `typo`, `copy`, `css`, `rename`, `comment`, `string-literal`, `version-bump`

   If ANY condition fails → assign `tier: "standard"`. NEVER mis-classify standard work as trivial to skip the grill.
3. **Grill (standard tier only)** — ask one concrete question per turn until scope, ambiguity, and acceptance are clear. NEVER ask the operator anything the codebase, ADRs, or existing tests can answer. Trivial tier → SKIP this step.
4. **Capture + present in ONE block** — build the JSON intent (declares `tier`, `asks[]`, `routing` per file or per ask) and present it together with the routing declaration. NEVER present intent and routing in separate turns.
5. **Single confirmation** — wait for ONE explicit "dale" / "procedé" / "approved". This single approval covers BOTH intent and routing. NEVER request a second approval for routing — the v4.4 double round-trip was deprecated in v4.5.
6. **Persist + execute** — write the artifacts (see "Per-tool enforcement" below) and execute per the declared routing.

### Per-tool enforcement

| Aspect | Claude Code (with hooks) | Opencode / Codex / Gemini / Cursor (no hooks) |
|---|---|---|
| Tier assignment | Self-enforced by agent | Self-enforced by agent |
| Grill if standard | Self-enforced; marker hook backstops | Self-enforced |
| Single combined presentation | Self-enforced | Self-enforced |
| Operator confirmation (one "dale") | Self-enforced | Self-enforced |
| Marker file `.intent-and-routing-confirmed-<ISO>` | **MUST write** — consumed by `pre-edit-intent-gate.sh` and `pre-task-routing-gate.sh` | **NEVER write** — no hook to consume; would create stale files |
| `docs/intents/<id>.md` (standard tier only) | **MUST write** to disk; bundled commit at slice close | **MUST write** to disk; bundled commit at slice close |
| `docs/intents/<id>.md` (trivial tier) | NEVER created — recorded in session journal at slice close | NEVER created — recorded in session journal at slice close |
| Per-turn auto-injected reminder | YES — slim ~95-token reminder via UserPromptSubmit hook | NO — opencode loads `rules/core/intent-capture-required.md` once via `opencode.json` |
| `BATUTA_INTENT_BYPASS=1` env var | Honored by hooks | Not applicable (no enforcement to bypass) |

### Commit policy (tool-portable)

- Discovery artifacts (`docs/intents/<id>.md`, `docs/plans/active/<file>.md`, `docs/sessions/<file>.md`) MUST be written to disk immediately at their canonical `docs/` paths.
- Discovery artifacts MUST NOT be committed individually. They bundle into the slice-close commit alongside the code that motivated them, OR into a single final `docs: close slice <id>` commit if the slice ended without code.
- The user-level rule "Commit after every meaningful change" applies to code; documentation-only churn during discovery is NOT a meaningful change in itself.
- Survival to compaction is preserved by the file's presence on disk: `session-start.sh` (Claude Code) and equivalent session-bootstrap mechanisms surface uncommitted `docs/` files via `git status`.

### NEVER do these

- NEVER skip the tier assignment and assume "this is small, I'll grill anyway" or "this is small, I'll just edit". Tier is the explicit decision.
- NEVER classify a multi-file refactor or a change that introduces control flow as trivial tier, regardless of file count.
- NEVER present intent in one turn and routing in a later turn — they MUST be in the same block.
- NEVER write a marker file in opencode / Codex / Gemini / Cursor — those tools have no hooks to read it; the file becomes orphan state.
- NEVER commit `docs/intents/<id>.md` as a standalone commit. It bundles at slice close.
- NEVER skip persisting `docs/intents/<id>.md` for standard-tier asks — it is the audit trail equivalent to an ADR.
- NEVER act on a `Next:` line from a session journal as authoritative direction; treat it as input to re-confirm with the operator.

## Cross-tool note (Codex CLI, Cursor, Aider, Gemini CLI, Windsurf)

Tools other than Claude Code 1.x do not support PreToolUse hooks, the `Task` subagent model, or the runtime audit chain. **The doc graph (`docs/PRD.md`, `docs/SPEC.md`, `docs/adr/`, `docs/plans/`, `docs/sessions/`) is plain Markdown and ports 100%.** The agent definitions in `agents/*.md` describe the contract but cannot be invoked as Tasks outside Claude Code.

If you are running this repository in a tool other than Claude Code:

1. Read `docs/PRD.md` first (project vision)
2. Read `docs/SPEC.md` second (architecture)
3. Read `docs/plans/active/*.md` (in-flight work)
4. Read the most recent `docs/sessions/*.md` and follow its `Next:` line
5. **Self-enforce Rule #0** — do not edit source code; produce the same artifacts the agents would have produced (build-log, audit report) by hand. The doc graph survives the lack of runtime enforcement.

Full handoff checklist: [`docs/PORTABILITY.md`](docs/PORTABILITY.md).

## OpenCode Integration

OpenCode uses a **skill-driven execution model** powered by the `skill` tool. This plugin ships a complete opencode interop layer at `.opencode/` validated end-to-end with DeepSeek V4 Pro via OpenRouter (see [`docs/opencode-setup.md`](docs/opencode-setup.md) for the bring-up notes and the IC-009/IC-010 sweep findings).

### What ships for OpenCode consumers

- `.opencode/skills` — symlink to the plugin's `skills/` directory (zero duplication; opencode reads SKILL.md descriptions on-demand).
- `.opencode/agents/*.md` (9) — opencode-shaped frontmatter (`mode: subagent`, `permission`, OpenRouter model IDs).
- `.opencode/commands/*.md` (13) — opencode-shaped frontmatter (`description`, `agent: build`).
- `opencode.json` (root) — provider config: OpenRouter, model defaults, **reasoning disabled** for DeepSeek to avoid empty-content timeouts, `instructions` glob to `rules/`.
- `.opencode/AGENTS.md.template` — the strict opencode contract (Class A/B/C action-vs-analysis, MUST/NEVER, anti-rationalizations, pre-tool-call checklist). Consumers copy to their project root as `AGENTS.md`.

### Core rules (model behavior contract)

- For each user message: skim `.opencode/skills/` descriptions; if any apply, invoke `skill({name})` and follow the skill's procedure exactly. NEVER skip a skill because the task seems trivial.
- Distinguish Class A (action requests, MUST grill) vs Class B (analysis/lookup/audit, act directly) vs Class C (ambiguous, ask which mode). The full procedure lives in `.opencode/AGENTS.md.template`.

### Intent → skill mapping

- Feature / new functionality → `spec-driven-development`, then `incremental-implementation`, `test-driven-development`
- Planning / breakdown → `planning-and-task-breakdown`
- Bug / failure / unexpected behavior → `debugging-and-error-recovery`
- Code review → `code-review-and-quality`
- Refactoring / simplification → `code-simplification`
- API or interface design → `api-and-interface-design`
- UI work → `frontend-ui-engineering`
- Security / vulnerability concern → `security-and-hardening`
- Performance / latency → `performance-optimization`
- Documentation / decision → `documentation-and-adrs`

### Lifecycle Mapping (Implicit Commands)

OpenCode does not support slash commands like `/spec` or `/plan`.

Instead, the agent must internally follow this lifecycle:

- DEFINE → `spec-driven-development`
- PLAN → `planning-and-task-breakdown`
- BUILD → `incremental-implementation` + `test-driven-development`
- VERIFY → `debugging-and-error-recovery`
- REVIEW → `code-review-and-quality`
- SHIP → `shipping-and-launch`

### Execution Model

For every request:

1. Determine if any skill applies (even 1% chance)
2. Invoke the appropriate skill using the `skill` tool
3. Follow the skill workflow strictly
4. Only proceed to implementation after required steps (spec, plan, etc.) are complete

### Anti-Rationalization

The following thoughts are incorrect and must be ignored:

- "This is too small for a skill"
- "I can just quickly implement this"
- "I’ll gather context first"

Correct behavior:

- Always check for and use skills first

This ensures OpenCode behaves similarly to Claude Code with full workflow enforcement.

## Creating a New Skill

### Directory Structure

```
skills/
  {skill-name}/           # kebab-case directory name
    SKILL.md              # Required: skill definition
    scripts/              # Required: executable scripts
      {script-name}.sh    # Bash scripts (preferred)
  {skill-name}.zip        # Required: packaged for distribution
```

### Naming Conventions

- **Skill directory**: `kebab-case` (e.g. `web-quality`)
- **SKILL.md**: Always uppercase, always this exact filename
- **Scripts**: `kebab-case.sh` (e.g., `deploy.sh`, `fetch-logs.sh`)
- **Zip file**: Must match directory name exactly: `{skill-name}.zip`

### SKILL.md Format

```markdown
---
name: {skill-name}
description: {One sentence describing when to use this skill. Include trigger phrases like "Deploy my app", "Check logs", etc.}
---

# {Skill Title}

{Brief description of what the skill does.}

## How It Works

{Numbered list explaining the skill's workflow}

## Usage

```bash
bash /mnt/skills/user/{skill-name}/scripts/{script}.sh [args]
```

**Arguments:**
- `arg1` - Description (defaults to X)

**Examples:**
{Show 2-3 common usage patterns}

## Output

{Show example output users will see}

## Present Results to User

{Template for how Claude should format results when presenting to users}

## Troubleshooting

{Common issues and solutions, especially network/permissions errors}
```

### Best Practices for Context Efficiency

Skills are loaded on-demand — only the skill name and description are loaded at startup. The full `SKILL.md` loads into context only when the agent decides the skill is relevant. To minimize context usage:

- **Keep SKILL.md under 500 lines** — put detailed reference material in separate files
- **Write specific descriptions** — helps the agent know exactly when to activate the skill
- **Use progressive disclosure** — reference supporting files that get read only when needed
- **Prefer scripts over inline code** — script execution doesn't consume context (only output does)
- **File references work one level deep** — link directly from SKILL.md to supporting files

### Script Requirements

- Use `#!/bin/bash` shebang
- Use `set -e` for fail-fast behavior
- Write status messages to stderr: `echo "Message" >&2`
- Write machine-readable output (JSON) to stdout
- Include a cleanup trap for temp files
- Reference the script path as `/mnt/skills/user/{skill-name}/scripts/{script}.sh`

### Creating the Zip Package

After creating or updating a skill:

```bash
cd skills
zip -r {skill-name}.zip {skill-name}/
```

### End-User Installation

Document these two installation methods for users:

**Claude Code:**
```bash
cp -r skills/{skill-name} ~/.claude/skills/
```

**claude.ai:**
Add the skill to project knowledge or paste SKILL.md contents into the conversation.

If the skill requires network access, instruct users to add required domains at `claude.ai/settings/capabilities`.
