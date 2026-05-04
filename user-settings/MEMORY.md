# MEMORY index — jota-batuta

> **Note (Claude Code 2.1.x)**: user-level memory at `~/.claude/MEMORY.md` is no longer the canonical mechanism. Auto-memory now lives **per-project** under `~/.claude/projects/<project>/memory/MEMORY.md` (see the new `## Memory in Claude Code 2.1.x` section in `README.md`). The two entries below are kept here as **reusable reference material** — they can be copied into a project's auto-memory directory or absorbed into a project's `CLAUDE.md` as needed.

## Reusable reference entries

- [Sanitize PII in public repos](memory/feedback_sanitize_public_repos.md) — abstract client names and CO-specific vendor names before any commit to a public repo
- [External docs and standards](memory/reference_external_docs.md) — Claude Code docs, AGENTS.md spec, Spec Kit, Obsidian KB pipeline (ADR-0012)

## What used to be here

The previous version of this index pointed at five additional entries:

- `feedback_no_ai_attribution.md` — superseded by the **PR policy** section in `~/.claude/CLAUDE.md` (rule 4: "Commits must not include `Co-Authored-By: Claude` or any AI attribution").
- `feedback_pr_policy.md` — superseded by the same **PR policy** section in `~/.claude/CLAUDE.md`.
- `user_operator_profile.md` — superseded by the **Language policy** + section headers in `~/.claude/CLAUDE.md` (Spanish convo / English artifacts).
- `feedback_hook_acceptedits_caveat.md` — stale: v2.7 changed hook semantics from workflow-gate to kill-switch-only ([ADR-0006](../docs/adr/0006-trust-native-delegation.md)). The caveat no longer applies.
- `reference_paths.md` — stale: paths are post-WSL-migration (`~/.claude/...` resolves under `/home/jnmz/...` on this machine, not `/mnt/c/Users/JNMZ/...`).

These entries are removed from the backup. Recover from git history if needed (`git log --all --oneline -- user-settings/memory/`).
