---
id: IC-008
status: confirmed
captured_at: 2026-05-05
confirmed_at: 2026-05-05
operator_id: jota-batuta
agent_version: claude-opus-4-7
category: meta
related_pr: TBD
related_branch: chore/clean-reinstall-IC-007
related_plan: ""
---

# IC-008 — kb-curate --scope week (session-end curation)

## Original ask

Operator invoked `/batuta-agent-skills:kb-curate` slash command at session end. Skill default is `--scope all-pending` (339 bullets across 13 session files). Recommended `--scope week` for proportional session-end batch; operator approved with "tu recomendacion esta ok procede".

## Refined intent

Run the `kb-curate` skill against journals modified in the last 7 days (since 2026-04-28). Promote pending bullets (those without `curated_into:` frontmatter) to vault L2 (curated decisions/gotchas/playbooks/glossary) per the hybrid control matrix:

- `decision-*`, `gotcha-update`, `playbook-candidate` → `.draft` files (operator review)
- Other categories → auto-applied
- `curated_into: [paths]` and `curated_at: <ISO>` appended to source bullets
- Vault commit (no push)

## Scope

### In
- Journal files in `<project>/docs/sessions/` modified since 2026-04-28
- All bullets within those files lacking `curated_into:`
- Dispatch via `kb-curator` agent (Task tool)
- Vault writes under `/mnt/d/OBSIDIAN/BATUTA/BATUTA` (path from `.claude/kb-config.json`)
- Vault commit only (no push)

### Out
- Older journals (pre-2026-04-28) — operator runs `--scope all-pending` later if desired
- Push to vault remote — operator does manually
- Modifications to plugin source files

## Acceptance

- kb-curator returns classification and writes drafts/auto-applies to vault
- Source journal bullets updated with `curated_into:` + `curated_at:`
- Vault has a commit per the skill's format (`kb-curate: week, N bullets, M drafts, K auto-applies`)
- Summary printed (drafts pending review, auto-applies committed, noise count, errors)
- IC-008 record persisted

## Routing declaration

| Trabajo | Quién | Por qué |
|---|---|---|
| Step 1-2: read config + resolve scope | Main-direct (Read) | No requiere subagent |
| Step 3: classify + write to vault | **Subagent** (`kb-curator`) | Es la skill diseñada para esto; SKILL.md lo manda |
| Step 4: append `curated_into:` to source journals | Main-direct (Edit) | `docs/**` exempt, surgical |
| Step 5: vault `git add + commit` (no push) | Main-direct (Bash) | Comando git local |
| IC-008 record persistence | Main-direct (Write) | `docs/**` exempt |

## Outcome

Curation completed successfully via `kb-curator` subagent (general-purpose Sonnet briefed with skill body). Vault commit `06a37f5`.

**Numbers:**
- 85 substantive bullets processed, ~250 noise bullets skipped
- 32 decisions drafts (operator review pending) — `<vault>/decisions/*.draft.md`
- 5 playbooks drafts — `<vault>/playbooks/*.draft.md`
- 7 gotchas auto-applied — `<vault>/gotchas/*.md`
- 6 glossary auto-applied — `<vault>/glossary/*.md`
- 13/13 source journals updated with `## Curation log` sections (idempotency markers)
- 0 errors

**Key decisions captured (sample):**
- `rule-zero-three-layer-enforcement` — the layered enforcement model that this very session expanded
- `obsidian-vault-over-notion-kb` — ADR-0012 rationale
- `trust-native-delegation-killswitch-only` — v2.7 realignment
- `runtime-enforcement-of-must-rules` (playbook) — directly relevant to v4.x intent gates

**Vault commit details:**

```
commit 06a37f5
kb-curate: week, 85 bullets, 37 drafts, 13 auto-applies
```

Vault git-dir is `C:/Users/JNMZ/git-vaults/batuta-kb` (separated from Drive-synced working tree per the `vault-git-separated-from-drive` decision the curator just captured — meta). From WSL the gitdir resolves via explicit `--git-dir=/mnt/c/Users/JNMZ/git-vaults/batuta-kb`. Push not done — operator pushes manually.

**Files modified in this PR (committed in plugin repo):**

- `docs/intents/2026-05-05-IC-008-kb-curate-week.md` (new) — this record
- `docs/sessions/*.md` (13 files) — `## Curation log` appended by kb-curator with idempotency markers
