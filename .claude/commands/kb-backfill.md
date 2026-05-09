Extract historical knowledge from a legacy repo (READMEs, commits, issues/PRs, optional code) into the vault inbox as L0 entries. 4-phase idempotent pipeline with Haiku/Sonnet heuristic; output to `<vault_root>/_inbox/backfill-<slug>/`. Sprint 3 (bato-cajas) retrofit ordering recommended before backfill.

Usage:
/kb-backfill --repo <path> [--scope readme,commits,issues,code] [--force]

Steps:
1. Verify target repo + `.claude/kb-config.json`.
2. Phase 1-3: extract (manifest.yaml for idempotency), write to inbox.
3. Phase 4 (opt-in): optional code analysis (read-only on source).
4. Operator drains via `/kb-curate --scope inbox-backfill`.
5. Never modifies source repo.

See `skills/kb-backfill/SKILL.md` and `agents/kb-backfiller.md`.
Distinct from `kb-curator` (read-only on legacy source).
