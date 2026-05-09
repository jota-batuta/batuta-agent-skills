[GOAL]: Ship a complete Claude Code plugin baseline for Batuta agent skills.

[CURRENT STATE]: Hardening pass complete on this branch. WP1 (code-graph removal), WP2 (hooks analysis), WP3 (3-tier Low/Mid/High routing), WP4 (living-docs-maintenance skill + CLAUDE.md + 3 auditors hardened) done. WP5 deferred. All changes staged. Ready for commit.

[NEXT ACTIONS]: Run final audit chain on the complete diff, then prepare a conventional commit if requested by the operator.

[AUTOMATION LOG]: Added `tools/validate-plugin.sh` to validate manifests, frontmatter, static validators, hook suites, and diff whitespace with one command.
