# Batuta Agent Skills

A Claude Code plugin that gives AI coding agents structured engineering workflows, automated quality gates, and durable project memory. Forked from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills).

## Read first

1. [`docs/PRD.md`](docs/PRD.md) -- vision, problem, success metrics
2. [`docs/SPEC.md`](docs/SPEC.md) -- architecture (11 layers)
3. [`CLAUDE.md`](CLAUDE.md) -- conventions and session-handoff protocol

## What the plugin ships

| Component | Count | Location |
|-----------|-------|----------|
| Skills (upstream) | 21 | `skills/` |
| Skills (Batuta) | 20 | `skills/` |
| Skills (vendored) | 2 | `skills/_vendored/` |
| Agents | 9 | `agents/` |
| Rules | 8 | `rules/core/`, `rules/authoring/` |
| Hooks | 14 | `hooks/` |
| ADRs | 16 | `docs/adr/` |

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

### Key skills (Batuta layer)

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `batuta-project-hygiene` | Session start / new feature | Bootstraps CLAUDE.md, doc graph, GitHub repo |
| `intent-capture` | Every operator action request | Captures confirmed intent before execution |
| `research-first-dev` | Before uncited external imports | Context7 lookup + `// Source:` citation |
| `batuta-skill-authoring` | Before new SKILL.md | Discovery gate against 91k+ skills.sh catalog |
| `batuta-agent-authoring` | Before new agent definition | Distinctness check against existing agents |
| `batuta-rule-authoring` | Before new rule file | Validates format + N=2 admission gate |
| `code-graph` | Architecture/dependency questions | Queries codebase-memory-mcp graph |
| `kb-end-session` | End of session | Closes session journal, triggers curation |

### Rules

Declarative invariants consumer projects import via `@.claude/rules/<rule>.md`. Symlinks created by `tools/setup-rules.sh`.

- `core/research-first-citations.md` -- every external import needs a `// Source:` citation
- `core/secrets-and-pii.md` -- secrets and PII boundaries
- `core/code-style.md` -- naming, docstrings, file size
- `core/intent-capture-required.md` -- intent-capture protocol
- `core/model-routing.md` -- model selection for subagents
- `core/no-hardcoded-magic.md` -- no magic numbers/strings
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

```
/plugin marketplace add jota-batuta/batuta-agent-skills
/plugin install batuta-agent-skills@batuta-agent-skills
```

For local development:

```bash
git clone https://github.com/jota-batuta/batuta-agent-skills.git
claude --plugin-dir /path/to/batuta-agent-skills
```

One-time code-graph bootstrap:

```bash
bash ~/.claude/plugins/marketplaces/batuta-agent-skills/tools/setup-code-graph.sh
```

## Repo structure

```
batuta-agent-skills/
├── agents/              # 9 agent definitions with explicit model: declarations
├── docs/
│   ├── PRD.md           # Vision and success metrics
│   ├── SPEC.md          # Architecture (11 layers)
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
├── tools/               # Setup scripts (rules import, code-graph bootstrap)
├── CLAUDE.md            # Project conventions
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
