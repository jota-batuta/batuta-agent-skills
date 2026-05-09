# Batuta Agent Skills

A Claude Code plugin for building multi-tenant, AI-first software with structured workflows, runtime enforcement, audit gates, and durable Obsidian memory. Forked from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills).

## Read first

1. [`docs/BASELINE.md`](docs/BASELINE.md) -- operative Claude Code plugin contract
2. [`docs/SKILL_MAP.md`](docs/SKILL_MAP.md) -- active skill consolidation map
3. [`docs/CLAUDE_CODE_DELIVERY.md`](docs/CLAUDE_CODE_DELIVERY.md) -- install, validation, and release gate
4. [`docs/PRD.md`](docs/PRD.md) -- vision, problem, success metrics
5. [`docs/SPEC.md`](docs/SPEC.md) -- architecture
6. [`user-settings/CLAUDE.md`](user-settings/CLAUDE.md) -- global machine-level rules (source of truth for multi-tenant, AI-first, prior-art-first, intent-capture)

## What the plugin ships

The supported runtime is Claude Code, through one of two paths:

1. Installed plugin.
2. Clone repo loaded with `claude --plugin-dir /path/to/batuta-agent-skills`.

Both paths should expose the same contract:

| Component | Role |
|-----------|------|
| `hooks/` | Claude Code lifecycle enforcement for intent, routing, PR safety, authoring gates, session context, and KB capture |
| `agents/` | Implementation, testing, review, security, architecture, and KB roles with explicit model routing |
| `skills/` | Short workflows for planning, building, reviewing, shipping, and operating the KB |
| `rules/` | Declarative engineering invariants imported by consumer projects |
| `.claude/commands/` | Operator entry points for repeatable workflows |
| `docs/` | Baseline, PRD, SPEC, ADRs, active plans, and session journals |

### Agents

| Agent | Model | Role |
|-------|-------|------|
| `implementer` | sonnet | Spec-driven implementation |
| `implementer-haiku` | haiku | Trivial changes (CSS, rename, config, <=3 files) |
| `code-reviewer` | sonnet | GATE 2 -- five-axis review |
| `test-engineer` | sonnet | GATE 1 -- test design and coverage |
| `security-auditor` | sonnet | GATE 3 -- OWASP vulnerability scan |
| `agent-architect` | sonnet | Creates project-local domain specialists |
| `kb-pipeline` | sonnet | Per-commit vault writes (Capture/Curate/Write) |
| `kb-curator` | sonnet | Batch L1->L2 promotion |
| `kb-backfiller` | sonnet | One-shot historical extraction |

After any implementation, a sequential audit chain runs: `test-engineer` -> `code-reviewer` -> `security-auditor`.

### Key workflows

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `batuta-project-hygiene` | Session start / new feature | Bootstraps CLAUDE.md, doc graph, GitHub repo |
| `intent-capture` | Every operator action request | Captures confirmed intent before execution |
| `research-first-dev` | Before uncited external imports or API use | Prior-art-first lookup + source citation |
| `batuta-skill-authoring` | Before new SKILL.md | Discovery gate against 91k+ skills.sh catalog |
| `batuta-agent-authoring` | Before new agent definition | Distinctness check against existing agents |
| `batuta-rule-authoring` | Before new rule file | Validates format + N=2 admission gate |
| `kb-end-session` | End of session | Closes session journal, triggers curation |

`code-graph` is deprecated in the active baseline. Use `codebase-flow-mapper` for version-controlled architecture diagrams and grep/read for live call-site queries.

### Rules

Declarative invariants consumer projects import via `@.claude/rules/<rule>.md`. Symlinks created by `tools/setup-rules.sh`.

- `core/research-first-citations.md` -- every external import needs a `// Source:` citation
- `core/secrets-and-pii.md` -- secrets and PII boundaries
- `core/code-style.md` -- naming, docstrings, file size
- `core/intent-capture-required.md` -- intent-capture protocol
- `core/model-routing.md` -- model selection for subagents
- `core/no-hardcoded-magic.md` -- no magic numbers/strings
- `core/tenant-ready-design.md` -- multi-context logic via profiles/adapters/rules/fixtures
- `authoring/skill-authoring-required.md` -- skill authoring gate
- `authoring/agent-authoring-required.md` -- agent authoring gate

### Hooks

14 hooks enforce constraints at runtime:

- **SessionStart:** `session-start.sh` (vault context injection)
- **UserPromptSubmit:** `clear-intent-marker.sh` (intent marker lifecycle)
- **PreToolUse gates:** intent gate, routing gate, delegation guard, skill/agent/feature write gates, PR merge/create guards, citation warnings, plan persistence, hooks health check

### Knowledge pipeline (Obsidian vault)

Per-commit auto-capture to an Obsidian vault with four levels: L0 (inbox), L1 (journals), L2 (curated decisions/gotchas/playbooks), L3 (glossary). Configured via `.claude/kb-config.json`.

## Install

Installed plugin path:

```
/plugin marketplace add jota-batuta/batuta-agent-skills
/plugin install batuta-agent-skills@batuta-agent-skills
```

Clone repo path:

```bash
git clone https://github.com/jota-batuta/batuta-agent-skills.git
claude --plugin-dir /path/to/batuta-agent-skills
```

`docs/PORTABILITY.md` is legacy emergency-handoff guidance for other tools. OpenCode, Codex, Cursor, Aider, Gemini CLI, and Windsurf are not active targets for this deliverable.

Validate the full Claude Code plugin contract with:

```bash
bash tools/validate-plugin.sh
```

## Repo structure

```
batuta-agent-skills/
├── agents/              # 9 agent definitions with explicit model: declarations
├── docs/
│   ├── BASELINE.md      # Operative Claude Code plugin contract
│   ├── PRD.md           # Vision and success metrics
│   ├── SPEC.md          # Architecture
│   ├── adr/             # 16 architecture decision records
│   ├── plans/           # Active and archived implementation plans
│   ├── sessions/        # Session journals (handoff protocol)
│   └── usage/           # Operator recipes
├── hooks/               # 14 runtime hooks (SessionStart, UserPromptSubmit, PreToolUse)
├── rules/
│   ├── core/            # Universal invariants
│   ├── authoring/       # Authoring gate rules
│   ├── delivery/        # Client handoff patterns (placeholder)
│   ├── stack/           # Stack-specific patterns (placeholder)
│   └── _meta/           # Import protocol and templates
├── skills/              # 41 skills + 2 vendored
├── references/          # Checklists (testing, security, performance, a11y)
├── tests/               # Static validators + E2E harness
├── tools/               # Setup and validation helpers
├── user-settings/       # Global machine-level rules (source of truth)
└── ATTRIBUTION.md       # Upstream and vendored source credits
```

## Vendored skills

| Skill | Origin | License |
|-------|--------|---------|
| `writing-skills` | obra/superpowers | MIT |
| `context7` | intellectronica/context7 | CC0 |

See [`ATTRIBUTION.md`](ATTRIBUTION.md) for full credits.

## License

MIT -- see [LICENSE](LICENSE).
