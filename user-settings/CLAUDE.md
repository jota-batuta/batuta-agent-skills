# User-level rules (jota-batuta)

Cross-project agent behavior. Project CLAUDE.md may narrow scope but cannot contradict.

## Language

- Conversations with operator: Spanish non verbose.
- Artifacts (code, README, SKILL.md, commit messages, PR descriptions, ADRs, tests): English.
- Client-facing user guides may be Spanish if the project CLAUDE.md states so.

## Research before code

- Vault L2 lookup first (Obsidian) — if a curated entry exists with `last_verified` < 4 months, it supersedes external lookup.
- Otherwise, Context7 for the exact version in the manifest.
- Fallback: web search on official documentation domain or library GitHub.
- Add `// Source: <url> (verified YYYY-MM-DD, <lib>@<version>)` at the import site.

Trust is not a substitute for verification. Enforced by `research-first-dev`.

## Divergent then convergent

For any non-trivial decision (architecture, data model, flow, stack):

1. List ≥3 viable approaches; include the obviously-right one. Do not collapse early.
2. Pick one; for each rejected alternative state the concrete reason (cost, complexity, scope, risk).
3. Record as ADR or session note.

## Git

- Commit after every meaningful change. **Discovery artifacts** (`docs/intents/<id>.md`, `docs/plans/active/<file>.md`, `docs/sessions/<file>.md`) are NOT meaningful changes by themselves — they bundle into the slice-close commit alongside the code that motivated them. Never end a session with a dirty tree of code; uncommitted discovery artifacts are expected mid-slice.
- New project: `gh repo create` and first commit before any feature code. The repo is the project.
- Every change → PR. Claude opens, operator merges. No `Co-Authored-By: Claude`.
- `git add <specific files>`, never `-A` outside fresh scaffolds.

## Authoring gates

Before creating any of the following files, the agent MUST invoke the corresponding skill, which writes a marker authorizing the file creation. PreToolUse hooks block the Write without a fresh marker.

| Path                               | Skill                      |
| ---------------------------------- | -------------------------- |
| `**/skills/**/SKILL.md` (plugin) | `batuta-skill-authoring` |
| `**/agents/**.md` (plugin)       | `batuta-agent-authoring` |
| `<project>/.claude/agents/**.md` | `agent-architect`        |
| `**/rules/**.md` (plugin)        | `batuta-rule-authoring`  |

Editing existing files in those paths is unrestricted. Bypass via the corresponding `BATUTA_*_BYPASS=1` env var on the launching shell. Mechanism details in `rules/authoring/`.

## Intent capture (every operator turn) — v4.6

Before any `Edit`/`Write`/`Bash`/`Task` tool call:

1. Detect: action request / continuation / read-only question.
2. **Tier assignment** — trivial IFF ALL FIVE: ≤3 files, ≤20 LOC, no new control flow, no new dep, category in `typo`/`copy`/`css`/`rename`/`comment`/`string-literal`/`version-bump`. Else standard.
3. Standard tier → grill (one Q per turn) until scope/acceptance clear. Trivial tier → skip grill.
4. Capture JSON intent (declares `tier`) → present in ONE block with the routing declaration (subagent vs main-direct per file or scope).
5. Immediately write pending marker `<project>/.claude/.intent-pending-<ISO>` (contains SHA256 of intent JSON) IN THE SAME RESPONSE as Step 4 — before the operator replies. The `clear-intent-marker.sh` hook promotes it to `.intent-and-routing-confirmed-<ISO>` when the operator sends the confirmation. Do NOT wait until after confirmation to write the marker: the hook runs at the START of the operator's turn, so a marker written after "dale" arrives is always one turn late.
6. Wait for SINGLE operator confirmation ("dale", "procedé", "sí, go ahead") — covers both intent and routing. For standard tier: also write `<project>/docs/intents/<YYYY-MM-DD>-<id>-<slug>.md` to disk (NOT committed individually — bundles at slice close per Git policy). For trivial tier: no `docs/intents/` file.
7. Execute.

The UserPromptSubmit hook promotes pending→confirmed markers (two-phase, v4.6) and injects a routing classifier (~25 tokens) per turn. The gate checks for hook-written `.intent-and-routing-confirmed-*` markers — the model MUST NOT write confirmed markers directly (`delegation-guard.sh` blocks this). **The pending marker MUST be written in the same response as Step 4 (presenting intent), not after receiving the operator's "dale".** Subagents bypass via `agent_id`. Bypass: `BATUTA_INTENT_BYPASS=1` on the launching shell. Legacy markers `.intent-confirmed-*` and `.routing-confirmed-*` are honored for one release cycle. Full protocol in `rules/core/intent-capture-required.md` (also imported by opencode via `opencode.json`).

**Self-correction when you forget Step 5.** `pre-edit-intent-gate.sh` returns `exit 1` (non-blocking warning) on miss — when you see "RULE violated (intent-capture gate)" in stderr, the action tool call may have executed despite the gate violation. STOP anyway. The warning means you skipped Step 4–5 above. Do not paper over it because the command appeared to succeed. Apologize, retroactively present the JSON intent, write the `.intent-pending-<ISO>` marker, and wait for explicit operator confirmation before the next action tool call. Improvising around the gate because it didn't hard-block is the exact failure mode this rule prevents — discipline is the primary mechanism, the hook is a backstop only.

## Delegation

Delegation is the default for implementation; main retains orchestration.

- **Lookups, multi-file search, WebFetch, README surveys (>3 queries about a single topic)** → `Explore` or `general-purpose` (Sonnet). Single short read that feeds the very next tool call: main may do it directly.
- **Implementation in client code** → `implementer-haiku` (≤3 files, mechanical, no new control flow / tests / async) or `implementer` (control flow, tests, async, integrations, multi-module).
- **Domain expertise** → invoke `agent-architect` to create or reuse a project-local specialist at `<project>/.claude/agents/`. Discovery-first against project-local + user-global + plugin agents.
- **Main retains**: orchestration, intent grilling, routing decisions, synthesis, plugin meta-work (plans, memory entries, ADRs, rules, this CLAUDE.md).

Never delegate to Opus subagents (defeats cost). Subagents inherit confirmed intent.

After any staged diff, the audit chain runs unconditionally: `test-engineer` → `code-reviewer` → `security-auditor`. Each step reads `git diff`; NOT-APPLICABLE returns immediately on a clean tree.

**Living docs (PRD/SPEC/ADR) are mandatory and alive.** Before closing any slice:
1. Re-read the relevant sections of PRD (acceptance criteria), SPEC (architecture), and the latest ADR.
2. Update PRD checkboxes and "as-built" notes in SPEC.
3. Record any new trade-off or rejected alternative in an ADR (create or append).
4. The three auditors will BLOCK if no visible update to at least one living doc in the current slice diff.

After exiting plan mode, run `/save-plan <slug>` so the plan persists at `<project>/docs/plans/active/<YYYY-MM-DD>-<slug>.md`.

## Project hygiene (auto)

At session start, `batuta-project-hygiene` auto-invokes:

- `mode=project-init` when project markers exist (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `.git/`) but `CLAUDE.md` does not.
- `mode=project-retrofit` (silent) when `CLAUDE.md` exists but `docs/PRD.md` / `docs/SPEC.md` / `docs/plans/active/` / `docs/sessions/` / `.claude/kb-config.json` are missing.
- `mode=feature-init <name>` when the operator describes a new feature or slice.

**Feature files NEVER at project root.** Project structure determines placement: feature-oriented (`src|packages|app|crates/<feature>/`) or layered (`docs/features/<feature>/` for Django/Rails/FastAPI/Temporal where moving code would break worker registration). Detection logic and the full path tree live in the skill.

Scoped feature `CLAUDE.md` is ≤60 lines and only contains rules unique to the feature — does not restate user-level or project-level rules (Claude Code's nested loading inherits them).

## Obsidian KB

The vault is the single source of truth. Path resolved via `~/.claude/kb-vault.json` → `vault_root`.

- Per-session: `hooks/session-start.sh` injects client metadata, project status, last 3 sessions, active plan into context.
- Per-commit: `hooks/post-commit-kb.sh` writes a journal bullet and (when `.claude/kb-config.json` opts in) dispatches the `kb-pipeline` agent to curate.
- Manual: `/kb-curate` for batch L1→L2 promotion, `/kb-end-session` to close the session journal.

**Wikilink invariant**: every vault file must include inline `[[wikilinks]]` and a `related:` frontmatter list. Without them the graph view and `research-first-dev` Step 1.5 cannot find the entry.

The context window is not memory. The Obsidian vault is.

## Plugin rules

Engineering invariants ship in `batuta-agent-skills/rules/`. A project imports them à la carte from its CLAUDE.md via `@.claude/rules/<rule>.md`. The symlinks are created by `tools/setup-rules.sh` (run once per project, idempotent), point at the plugin install path, and update on `/plugin update`. Add `.claude/rules/` to project `.gitignore` (per-machine, breaks on clones without the plugin).

## Core invariants (required for Batuta multi-tenant AI-first)

These rules are non-negotiable. They MUST be imported in this global `~/.claude/CLAUDE.md` (or via `@user-settings/CLAUDE.md` in the plugin repo) so that Claude Code and all hooks are bound by them on every session. Without these imports, the skills and hooks have no enforcement contract.

Import them explicitly:

```markdown
@rules/core/tenant-ready-design.md
@rules/core/no-hardcoded-magic.md
@rules/core/research-first-citations.md
@rules/core/intent-capture-required.md
@rules/core/secrets-and-pii.md
@rules/core/code-style.md
@rules/core/model-routing.md
```

These rules enforce:
- **Multi-tenant from day zero**: All logic is parameterized by context (tenant, client, bank, environment, format, rule, period). No hard-coded values.
- **Prior-art-first (research-first)**: Copy before build. Evidence pack required for every external dependency.
- **Intent capture**: Every action is preceded by explicit intent declaration + operator confirmation. Trivial tier is narrowly defined.
- **No hardcoding**: Magic strings, tenant names, bank names, formats, credentials — all externalized.
- **Security & PII**: Never in repo, never in logs, never in client artifacts.
- **Code style & model routing**: Consistent style + correct model delegation.

The hooks (`pre-edit-intent-gate.sh`, `delegation-guard.sh`, `pre-write-skill-gate.sh`, etc.) and skills (`intent-capture`, `research-first-dev`, `batuta-project-hygiene`, etc.) derive their authority from these imports. If they are absent, the system degrades to generic Claude Code behavior.

## Boundaries

- Use subagents by specificity, not as fallback. Goal: keep main context under 50% utilization.
- Never block the main session waiting on long-running processes — `run_in_background: true` on Bash.
- Local `docker compose` first; cloud after local is proven.
- Secrets, auth keys, PII: never in the repo, never in plaintext logs, never in client-side code or static build artifacts.
- Operator help: `/help`. Feedback: github.com/anthropics/claude-code/issues.

* **Simplicity first** — favor the simplest implementation that solves the problem; complexity must justify itself.
* **Prefer simple code** — avoid premature abstraction, clever tricks, or layers that don't earn their keep.
* **Keep code simple** — readability and directness over cleverness.
