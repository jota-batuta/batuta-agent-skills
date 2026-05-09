[GOAL]: Ship a complete Claude Code plugin baseline for Batuta agent skills.

[CURRENT STATE]: Unifying pass active. All 3 v2.5 failures resolved (code-graph test updated for removal + 2 KB commands created); validate-plugin.sh green (15/15 PASS). Git rule: no merge without PR.

[NEXT ACTIONS]: Re-run validate-plugin.sh confirmed green; prepare conventional commit on branch (see prompt_log for details).

[AUTOMATION LOG]: Added `tools/validate-plugin.sh` to validate manifests, frontmatter, static validators, hook suites, and diff whitespace with one command.
