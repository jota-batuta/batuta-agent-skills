---
id: IC-016
slug: plugin-flow-fix-and-code-graph-deprecation
date: 2026-05-07
status: confirmed
---

# IC-016 — Plugin initial flow fix + code-graph deprecation

## Intent

Fix five compounding issues in the plugin's user-facing workflow:
1. session-start.sh project-init hint upgraded from soft suggestion to CRITICAL mandatory instruction
2. PostToolUse hook on ExitPlanMode auto-saves plan from ~/.claude/plans/ to docs/plans/active/
3. Doc layers (intents/sessions/plans) surfaced in session-start output and clarified in CLAUDE.md
4. code-graph skill deprecated (647-line infrastructure for non-blocking, zero-adoption optional enrichment; codebase-flow-mapper + grep+read cover the use cases)
5. Step 0.5 removed from code-reviewer.md and security-auditor.md agent definitions

## Scope

8 files:
- hooks/session-start.sh (edit)
- hooks/post-exit-plan-mode.sh (new)
- hooks/hooks.json (edit)
- agents/code-reviewer.md (remove Step 0.5)
- agents/security-auditor.md (remove Step 0.5)
- skills/code-graph/SKILL.md (replace with deprecation notice)
- rules/integrations/code-graph-usage.md (add deprecated frontmatter)
- CLAUDE.md (remove code-graph MUST trigger, add doc-layers table)

## Routing

- hooks/: implementer subagent (new script + edits with shell logic)
- agents/, skills/, rules/, CLAUDE.md: main-direct (plugin meta-work, existing files)
