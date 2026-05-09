Promote captured L1 journal bullets to curated L2/L3 decisions/gotchas/playbooks/glossary entries in the operator's Obsidian vault. Supports 4 invocation modes (PR-merge via GitHub Action, manual slash, weekly cron, session-end), 7-category classification, and hybrid auto-apply control matrix.

Usage:
/kb-curate [--feature <branch> | --scope session|week|all-pending|since-YYYY-MM-DD]

Steps:
1. Resolve scope from flags and `.claude/kb-config.json` (client/project/vault_root).
2. Load pending bullets (skip those with `curated_into:` frontmatter).
3. Delegate to `kb-curator` agent for classification table.
4. Operator reviews drafts; auto-apply or manual commit to vault.
5. Write audit trail and update STATUS.md where applicable.

See `skills/kb-curate/SKILL.md` for full pipeline and `agents/kb-curator.md` for the classification agent.
Companion: `/kb-end-session` triggers this with --scope session.
