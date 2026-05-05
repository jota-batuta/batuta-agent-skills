# OpenCode Setup

> **Scope disclaimer.** OpenCode replicates only the **skill-routing surface** of `batuta-agent-skills`. The Batuta runtime layer — Rule #0 PreToolUse hook, the audit chain (`AUDIT RESULT: APPROVED|BLOCKED` contract), the `Task` subagent delegation model, and the project-local specialist creation via `agent-architect` — is specific to Claude Code 1.x and does **not** port to OpenCode. The agent files in `agents/` describe the contract but cannot be invoked as Tasks in OpenCode.
>
> What you DO get on OpenCode: skill auto-discovery and intent → skill mapping (this document). What you DO NOT get: runtime hook enforcement, audit-chain blocking, Haiku/Sonnet/Opus model tier selection per delegation, `agent-architect` specialist creation. If you need those, run in Claude Code.
>
> If you are switching from Claude Code to OpenCode mid-feature, also read [`docs/PORTABILITY.md`](PORTABILITY.md) for the doc-graph handoff (PRD → SPEC → active plan → session journal) and how to self-enforce Rule #0 manually.

This guide explains how to use the skill-routing portion of Agent Skills with OpenCode (automatic skill selection, lifecycle-driven workflows, and process enforcement at the skill level).

## Overview

OpenCode supports custom `/commands`, but does not have a native plugin system or automatic skill routing like Claude Code.

Instead, we achieve parity through:

- A strong system prompt (`AGENTS.md`)
- The built-in `skill` tool
- Consistent skill discovery from the `/skills` directory

This creates an **agent-driven workflow** where skills are selected and executed automatically.

While it is possible to recreate `/spec`, `/plan`, and other commands in OpenCode, this integration intentionally uses an agent-driven approach instead:

- Skills are selected automatically based on intent
- Workflows are enforced via `AGENTS.md`
- No manual command invocation is required

This more closely matches how Claude Code behaves in practice, where skills are triggered automatically rather than manually.

---

## Installation

1. Clone the repository (or install via `/plugin install batuta-agent-skills@batuta-agent-skills` in Claude Code; both leave a checkout opencode can read):

```bash
git clone https://github.com/jota-batuta/batuta-agent-skills.git
cd batuta-agent-skills
```

2. **Set the OpenRouter API key out-of-repo and source it into the env**:

```bash
echo 'YOUR_OPENROUTER_API_KEY_HERE' > ~/.openrouter-key && chmod 600 ~/.openrouter-key
# Replace YOUR_OPENROUTER_API_KEY_HERE with your actual key from
# https://openrouter.ai/settings/keys (paste it inside the quotes).
export OPENROUTER_API_KEY=$(cat ~/.openrouter-key)
```

NEVER paste the literal key into `opencode.json`. The shipped `opencode.json` uses `{env:OPENROUTER_API_KEY}` template syntax.

3. Open the project in opencode:

```bash
opencode
```

4. Verify the integration is present:

- `AGENTS.md` (root) — cross-tool entry point
- `skills/` — canonical skill source (the symlink target for `.opencode/skills/`)
- `.opencode/skills/` — symlink → `../skills/`
- `.opencode/agents/*.md` (9) — opencode-shaped agent frontmatter
- `.opencode/commands/*.md` (13) — opencode-shaped slash commands
- `opencode.json` (root) — provider/model/permission/instructions
- `.opencode/AGENTS.md.template` — strict opencode contract; copy to your project root as `AGENTS.md` if you are running this plugin from a CONSUMER repo.

For a consumer repo (your own project that wants to adopt the plugin's interop layer), see "Consumer setup" below.

---

## How It Works

### 1. Skill Discovery

All skills live in:

```
skills/<skill-name>/SKILL.md
```

OpenCode agents are instructed (via `AGENTS.md`) to:

- Detect when a skill applies
- Invoke the `skill` tool
- Follow the skill exactly

### 2. Automatic Skill Invocation

The agent evaluates every request and maps it to the appropriate skill.

Examples:

- "build a feature" → `incremental-implementation` + `test-driven-development`
- "design a system" → `spec-driven-development`
- "fix a bug" → `debugging-and-error-recovery`
- "review this code" → `code-review-and-quality`

The user does **not** need to explicitly request skills.

### 3. Lifecycle Mapping (Implicit Commands)

The development lifecycle is encoded implicitly:

- DEFINE → `spec-driven-development`
- PLAN → `planning-and-task-breakdown`
- BUILD → `incremental-implementation` + `test-driven-development`
- VERIFY → `debugging-and-error-recovery`
- REVIEW → `code-review-and-quality`
- SHIP → `shipping-and-launch`

This replaces slash commands like `/spec`, `/plan`, etc.

---

## Usage Examples

### Example 1: Feature Development

User:
```
Add authentication to this app
```

Agent behavior:
- Detects feature work
- Invokes `spec-driven-development`
- Produces a spec before writing code
- Moves to planning and implementation skills

---

### Example 2: Bug Fix

User:
```
This endpoint is returning 500 errors
```

Agent behavior:
- Invokes `debugging-and-error-recovery`
- Reproduces → localizes → fixes → adds guards

---

### Example 3: Code Review

User:
```
Review this PR
```

Agent behavior:
- Invokes `code-review-and-quality`
- Applies structured review (correctness, design, readability, etc.)

---

## Agent Expectations (Critical)

For OpenCode to work correctly, the agent must follow these rules:

- Always check if a skill applies before acting
- If a skill applies, it MUST be used
- Never skip required workflows (spec, plan, test, etc.)
- Do not jump directly to implementation

These rules are enforced via `AGENTS.md`.

---

## Consumer setup (your project consumes the plugin via opencode)

If your project lives at `~/myapp/` and the plugin clone at `~/batuta-agent-skills/`:

```bash
cd ~/myapp
mkdir -p .opencode
ln -sf ~/batuta-agent-skills/skills .opencode/skills
ln -sf ~/batuta-agent-skills/.opencode/agents .opencode/agents
ln -sf ~/batuta-agent-skills/.opencode/commands .opencode/commands
cp ~/batuta-agent-skills/.opencode/AGENTS.md.template AGENTS.md
cp ~/batuta-agent-skills/opencode.json opencode.json
```

**The shipped `opencode.json` uses paths relative to the plugin clone, not your project. If you copy it verbatim, opencode will fail to load the rules.** Edit the `instructions` array to point at the plugin's `rules/` with the absolute path under your clone. Replace:

```json
  "instructions": [
    "./rules/core/code-style.md",
    "./rules/core/secrets-and-pii.md",
    ...
```

with (assuming the plugin lives at `~/batuta-agent-skills/`):

```json
  "instructions": [
    "/home/you/batuta-agent-skills/rules/core/code-style.md",
    "/home/you/batuta-agent-skills/rules/core/secrets-and-pii.md",
    "/home/you/batuta-agent-skills/rules/core/research-first-citations.md",
    "/home/you/batuta-agent-skills/rules/core/intent-capture-required.md",
    "/home/you/batuta-agent-skills/rules/core/model-routing.md",
    "/home/you/batuta-agent-skills/rules/core/no-hardcoded-magic.md",
    "/home/you/batuta-agent-skills/rules/authoring/skill-authoring-required.md",
    "/home/you/batuta-agent-skills/rules/authoring/agent-authoring-required.md",
    "/home/you/batuta-agent-skills/rules/integrations/code-graph-usage.md"
  ]
```

Then `opencode` from `~/myapp/` will load the 34 skills (via symlink), 9 agents, 13 commands, the strict AGENTS.md contract, AND the engineering invariants from `rules/`.

## OpenRouter / model considerations (validated under DeepSeek V4 Pro)

- `opencode.json` ships with `reasoning: { enabled: false }` for DeepSeek V4 Pro and Flash. **Do not remove it.** Without this, the model spends `max_tokens` producing chain-of-thought and never emits `content`, making opencode appear to hang and producing 0-byte responses on `opencode run --format json`. This was observed during the IC-009 sweep and fixed in IC-010.
- The strict `.opencode/AGENTS.md.template` distinguishes **Class A** (action — MUST grill before mutation) from **Class B** (analysis/lookup — answer directly). Without that distinction, the model gates EVERY message behind intent capture and the downstream skills never get to run. This was the dominant failure mode in the v1 IC-009 sweep.
- API key MUST come from `~/.openrouter-key` (chmod 600) sourced into `OPENROUTER_API_KEY`. The literal key NEVER lives in `opencode.json`. Use `{env:OPENROUTER_API_KEY}` template syntax.
- Default models in shipped `opencode.json`:
  - `model: openrouter/deepseek/deepseek-v4-pro` (1M context, ~$0.435 / $0.87 per Mtok)
  - `small_model: openrouter/deepseek/deepseek-v4-flash` (1M context, ~$0.14 / $0.28)
  - Kimi K2.6 (`openrouter/moonshotai/kimi-k2.6`, 256K context) is the documented fallback on rate-limit/outage. **The fallback is a manual swap** — edit `opencode.json` `model:` to `openrouter/moonshotai/kimi-k2.6` if DeepSeek is unavailable; opencode does not auto-failover between providers.

### Note on the `provider.openrouter.models` block (looks inconsistent but is correct)

In the shipped `opencode.json`:

- The top-level `model:` and `small_model:` use the **global ID prefix** `openrouter/<vendor>/<model>` (e.g. `openrouter/deepseek/deepseek-v4-pro`).
- The `provider.openrouter.models.<key>` block uses the **provider-scoped slug** without the `openrouter/` prefix (e.g. `deepseek/deepseek-v4-pro`).

Both forms are correct in their respective scopes. Do NOT "fix" the provider block to match the top-level — that would break the per-model `reasoning: { enabled: false }` override and the model would resume eating `max_tokens` on chain-of-thought.

## Limitations

- No native PreToolUse hooks (Claude-Code-only). The 9 bash hooks under `hooks/` do NOT run in opencode. The strict AGENTS.md contract compensates: the model is the only enforcement layer. If you need runtime gating on Edit/Write/Bash, run in Claude Code.
- No native slash commands (handled via intent mapping). The shipped `.opencode/commands/` provides the same lifecycle but invocation is through opencode's built-in `/<name>` syntax with the body of each command as the prompt template.
- Skill invocation depends on model compliance with `AGENTS.md` §1. Validated under DeepSeek V4 Pro: skill tool primitive IS invoked when reasoning is disabled and timeouts are sufficient (≥240s for first-prompt warm-up).

Despite these, the workflow closely matches Claude Code in practice.

---

## Recommended Workflow

Just use natural language:

- "Design a feature"
- "Plan this change"
- "Implement this"
- "Fix this bug"
- "Review this"

The agent will automatically select and execute the correct skills.

---

## Summary

OpenCode integration works by combining:

- Structured skills (this repo)
- Strong agent rules (`AGENTS.md`)
- Automatic skill invocation via reasoning

This results in a **fully agent-driven, production-grade engineering workflow** without requiring plugins or manual commands.
