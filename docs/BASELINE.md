# Baseline — Claude Code Plugin

**Status:** operative baseline
**Last reviewed:** 2026-05-08

This document is the current operating contract for `batuta-agent-skills`. Older PRDs, SPEC sections, ADRs, and portability notes remain useful history, but this file is the first document to read for the active deliverable.

## Target

The deliverable is a complete Claude Code plugin. It is not a cross-platform agent framework and does not attempt functional parity with OpenCode, Codex, Cursor, Aider, Gemini CLI, Windsurf, or other harnesses.

Supported execution paths:

1. **Installed plugin:** Claude Code loads the plugin through its native plugin mechanism.
2. **Clone repo:** Claude Code loads this repository directly with `claude --plugin-dir /path/to/batuta-agent-skills`.

Both paths must expose the same contract: hooks, agents, skills, rules, slash commands, and baseline docs.

The delivery checklist and validation command live in `docs/CLAUDE_CODE_DELIVERY.md`.

## Product Stance

The harness builds software that is multi-tenant and AI-first from day zero.

- Treat client, bank, environment, provider, file format, rule set, and effective date as context boundaries, even when a concrete project starts with one client.
- Keep variation outside core logic through profiles, adapters, config, fixtures, rules, or tenant/context metadata.
- Design artifacts so agents can inspect, test, and adapt them without relying on tribal knowledge.
- Prefer explicit contracts over implicit conventions when runtime behavior can vary by tenant or execution context.

## Research Stance

Research-first means prior-art-first.

Before inventing a workflow, rule, validator, hook, or integration pattern:

1. Look for proven prior art in official docs, upstream projects, mature OSS, ADRs, and the Obsidian vault.
2. Copy or adapt the reliable pattern when it fits the constraints.
3. Invent only when no trustworthy prior implementation matches the need.

The goal is velocity without novelty debt.

## Memory

Obsidian remains the operational memory. The plugin uses the vault for decisions, gotchas, playbooks, session history, and reusable project knowledge. Markdown docs in this repo are the source-controlled contract; the vault is the living memory that connects those contracts across clients and projects.

## Plugin Contract

A functional release must keep these surfaces aligned:

- **Hooks:** Claude Code lifecycle enforcement for intent, routing, PR safety, authoring gates, session context, and KB capture.
- **Agents:** implementation, testing, review, security, architecture, and KB roles with explicit model routing and clear audit contracts.
- **Skills:** short, actionable workflows that invoke the right process at the right time. `docs/SKILL_MAP.md` declares primary skills, compatibility wrappers, specialized workflows, and deprecated stubs.
- **Rules:** declarative engineering invariants imported by consumer projects.
- **Slash commands:** operator entry points for repeatable workflows.
- **Docs:** `README.md`, `docs/PRD.md`, `docs/SPEC.md`, ADRs, active plans, and session journals.

If a rule is critical to plugin behavior, it should be backed by a hook, validator, command, agent contract, or explicit review gate. Prose alone is not a functional contract.

## Out Of Scope

- Cross-tool portability as an active deliverable.
- OpenCode, Codex, Cursor, Aider, Gemini CLI, or Windsurf adapters.
- Removing compatibility skill names in this phase.
- Deleting historical ADRs or docs.
- Replacing Obsidian with another memory store.

`docs/PORTABILITY.md` is legacy guidance for emergency handoff into other tools. It is not part of the active plugin contract.
