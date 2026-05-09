[GOAL]: Ship a complete Claude Code plugin baseline for Batuta agent skills.

[CURRENT STATE]: Unifying pass active (new 6-layer plan). WP1 complete (code-graph removed, README updated). WP2: session-start.sh injects using-agent-skills + context-engineering + KB (~2-4k tokens) — known bloat source; actual slimming deferred. Git rule: no merge without PR.

[NEXT ACTIONS]: Run final audit chain on the complete diff, then prepare a conventional commit if requested by the operator.

[AUTOMATION LOG]: Added `tools/validate-plugin.sh` to validate manifests, frontmatter, static validators, hook suites, and diff whitespace with one command.
