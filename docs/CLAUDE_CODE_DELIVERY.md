# Claude Code Delivery

This document defines the functional delivery contract for `batuta-agent-skills`.
The active target is Claude Code only.

## Supported Paths

1. Installed plugin: Claude Code loads the package through `.claude-plugin/plugin.json` and the native plugin mechanism.
2. Clone repo: Claude Code loads this repository directly with `claude --plugin-dir /path/to/batuta-agent-skills`.

Both paths must expose the same surfaces: `.claude/commands/`, `hooks/hooks.json`, `agents/`, `skills/`, `rules/`, baseline docs, and Obsidian KB config when enabled.

## What Must Work

- Session start loads hooks health, project context, active plans, and KB context when configured.
- User prompt submit clears/promotes intent markers.
- PreToolUse gates enforce session context, intent, routing, delegation kill-switches, skill/agent/feature authoring, PR merge, and PR create rules.
- PostToolUse hooks persist plans and warn on missing research citations.
- Agents use the audit chain: `test-engineer` -> `code-reviewer` -> `security-auditor`.
- Skills stay short on the hot path and route to references for long examples.
- Rules include prior-art-first citations and tenant-ready design from day zero.

## Validation Command

Run from the repository root:

```bash
bash tools/validate-plugin.sh
```

The command validates JSON manifests, frontmatter shape, static validators, intent gates, authoring gates, hook additions, and whitespace in the current diff.

## Manual Smoke Checks

Installed plugin:

```text
/plugin marketplace add jota-batuta/batuta-agent-skills
/plugin install batuta-agent-skills@batuta-agent-skills
```

Clone repo:

```bash
claude --plugin-dir /path/to/batuta-agent-skills
```

In either path, confirm these commands are visible: `/build`, `/review`, `/test`, `/spec`, `/plan`, `/ship`, `/kb-curate`, `/kb-backfill`, `/kb-end-session`, `/batuta-status`, `/save-plan`.

## Out Of Scope

OpenCode, Codex, Cursor, Aider, Gemini CLI, Windsurf, and other harnesses are legacy handoff targets only. `docs/PORTABILITY.md` records historical guidance; it is not an active compatibility contract.

## Release Gate

A release is ready only when:

- `bash tools/validate-plugin.sh` passes.
- README, BASELINE, SPEC, and PRD agree that Claude Code is the only functional target.
- `docs/SKILL_MAP.md` reflects current skill ownership and wrappers.
- No hook or agent prompt permits direct push to `main` or bypasses audit gates.
- Multi-context behavior is checked by `rules/core/tenant-ready-design.md` and agent review prompts.
