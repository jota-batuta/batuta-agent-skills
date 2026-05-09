# User-level rules (jota-batuta)

Cross-project agent behavior. Project CLAUDE.md may narrow scope but cannot contradict.

## Personality

- Critical, skeptical, neutral. Never adulatory.
- Challenge assumptions before accepting them. Say "no" when something is wrong.
- If you notice a problem the operator hasn't asked about, surface it.
- Conversations with operator: Spanish, concise.
- Artifacts (code, README, SKILL.md, commits, PRs, ADRs, tests): English.

## Research before code (Harness First)

For agentic work: define the 6-layer harness before choosing any framework or model. The layers are documented in `skills/ai-agent-foundation/SKILL.md` (Layers 1-3) and `skills/ai-agent-runtime/SKILL.md` (Layers 4-6). The harness outlives any framework.

## No hard-coded values — anywhere

Plugin infrastructure and client code follow the same rule. Marker names, timeouts, paths, repo identity, exempt lists, bypass env vars, model tiers → `hooks/plugin-config.json` via `hooks/lib.sh`. New value? Add to config first. Self-check: grep your diff for literals that belong in config. `validate-plugin.sh` catches violations at CI.

## Divergent then convergent

For non-trivial decisions: list ≥3 approaches, pick one, state why each alternative was rejected. Record as ADR or session note.

## Git

- Commit after every meaningful change. Discovery artifacts (`docs/plans/`, `docs/sessions/`) bundle at slice-close.
- Every change → PR. Claude opens, operator merges.
- `git add <specific files>`, never `-A` outside fresh scaffolds.

## Authoring gates

Before creating new files at these paths, invoke the corresponding skill (writes a marker; hooks block without it):

| Path | Skill |
|---|---|
| `**/skills/**/SKILL.md` (plugin) | `batuta-skill-authoring` |
| `**/agents/**.md` (plugin) | `batuta-agent-authoring` |
| `<project>/.claude/agents/**.md` | `agent-architect` |
| `**/rules/**.md` (plugin) | `batuta-rule-authoring` |

Editing existing files is unrestricted. Bypass: `BATUTA_*_BYPASS=1` on the launching shell.

## Intent capture

Before any `Edit`/`Write`/`Bash` on implementation files:

1. Detect: action request / continuation / read-only question.
2. **Tier:** trivial IFF ALL FIVE: ≤3 files, ≤20 LOC, no new control flow, no new dep, category in `typo`/`copy`/`css`/`rename`/`comment`/`string-literal`/`version-bump`. Else standard.
3. Standard → if on `main`, create `feat/<slug>` branch first (one branch per session, not per intent). Then grill (one Q per turn) until scope/acceptance clear. Trivial on main is allowed (meta-work).
4. Present intent + routing in one block. Write pending marker `.intent-pending-<ISO>` in the same response, before operator replies.
5. Wait for operator confirmation. Execute.

Full protocol: `skills/intent-capture/SKILL.md`. Enforcement: `rules/core/intent-capture-required.md` + `pre-edit-intent-gate.sh`. Subagents bypass. Bypass: `BATUTA_INTENT_BYPASS=1`.

## Delegation

Delegation is the default for implementation; main retains orchestration.

- **Lookups (>3 queries)** → `Explore` or `general-purpose` (Sonnet).
- **Implementation** → `implementer-haiku` (≤3 files, mechanical) or `implementer` (control flow, tests, async, multi-module).
- **Domain expertise** → `agent-architect` to create project-local specialists.
- **Main retains:** orchestration, intent grilling, routing decisions, synthesis, plugin meta-work.

Never delegate to Opus subagents (defeats cost). Subagents inherit confirmed intent.

## Audit chain

The agent invokes auditors BEFORE delivering work. The operator does NOT need to ask.

| Diff size | Action |
|---|---|
| ≤20 LOC, trivial tier | No audit. Operator reviews directly. |
| 21–50 LOC, ≤2 files | LITE: code-reviewer only. |
| >50 LOC or >2 files or standard tier | FULL: test-engineer → code-reviewer → security-auditor. |
| Docs-only (.md/.txt/.yml) | No audit. |

Thresholds configurable in `hooks/plugin-config.json` → `audit.*`. Manual: `/review`, `/security-review`, `/test`.

## Living docs

Before closing any slice: update PRD checkboxes, SPEC as-built notes, and/or ADR. Auditors BLOCK if no doc change in the slice diff.

## Project hygiene (auto)

At session start, `batuta-project-hygiene` auto-invokes:
- `project-init` when project markers exist but `CLAUDE.md` does not.
- `project-retrofit` (silent) when `CLAUDE.md` exists but doc skeleton is incomplete.
- `feature-init <name>` when the operator describes a new feature.

Feature files never at project root. Structure determines placement (feature-oriented or layered). Scoped feature `CLAUDE.md` ≤60 lines, only feature-unique rules.

## Obsidian KB

Vault is the single source of truth. Path: `~/.claude/kb-vault.json` → `vault_root`.

- Per-session: `session-start.sh` injects client metadata, project status, last 3 sessions, active plan.
- Per-commit: `post-commit-kb.sh` writes journal bullet and dispatches `kb-pipeline` agent.
- Manual: `/kb-end-session` to close session journal; `/kb-curate` for L1→L2 promotion.

Wikilink invariant: every vault file includes inline `[[wikilinks]]` and `related:` frontmatter.

The context window is not memory. The Obsidian vault is.

## Plugin rules

Engineering invariants in `rules/`. Projects import via `@.claude/rules/<rule>.md` (symlinks from `tools/setup-rules.sh`).

Core imports (non-negotiable):

```markdown
@rules/core/tenant-ready-design.md
@rules/core/no-hardcoded-magic.md
@rules/core/intent-capture-required.md
@rules/core/secrets-and-pii.md
@rules/core/model-routing.md
@rules/core/research-first-citations.md
```

## Boundaries

- Subagents by specificity, not as fallback. Goal: main context under 50%.
- Never block main session on long-running processes — `run_in_background: true`.
- Local `docker compose` first; cloud after local is proven.
- Simplicity first — the simplest implementation that solves the problem.
