# Changelog — batuta-agent-skills

All notable changes to this plugin are listed here.

## [6.0.0] — 2026-05-09

Production-grade refactor. Breaking: skills consolidated, hooks refactored, config externalized.

### Breaking changes
- **Skills 48 → 24.** Deleted 7 skills that restate Claude's native behavior (context-engineering, git-workflow-and-versioning, quality-axes, ci-cd-and-automation, shipping-and-launch, spec-driven-development, using-agent-skills). Simplified 16 skills to constraints-only (no tutorials).
- **Hooks 15 → 12.** Deleted clear-intent-marker.sh, post-edit-citation-warn.sh, pre-task-routing-gate.sh.
- **Rule deleted:** code-style.md (contradicts Claude Code system prompt).
- **Intent protocol simplified** (Option B): markers kept, JSON schema/docs-intents persistence removed.

### New
- **`hooks/plugin-config.json`** — single source of truth for all configurable values (markers, timeouts, paths, exempt lists, bypass env vars, audit thresholds).
- **`hooks/lib.sh`** — shared library sourced by all 12 hooks. Zero hard-coded values in hook logic.
- **Audit chain thresholds** — ≤20 LOC skip, 21-50 LOC lite (code-reviewer only), >50 LOC full chain. Configurable in plugin-config.json.
- **Hard-code detector** in validate-plugin.sh — scans hooks for literal values that belong in config.
- **`rules/core/session-context-gate.md`** and **`rules/authoring/feature-init-required.md`** — document the hooks that enforce them.
- **`docs/AUDIT_CHAIN.md`** — operator-facing one-pager explaining when/how auditors run.
- 8 new SKILL.eval.yaml files for hot-path skills (46% eval coverage, up from 10%).

### Fixed
- validate-plugin.sh no longer fails in the plugin repo (kb-config.json is consumer-project-only).
- Orphaned references linked to their parent skills.
- 4 audit-chain agents simplified to ~20 lines each (role + output format, no methodology tutorials).
- 4 rules simplified to constraints-only (no Claude-native advice).
- All commands updated to reference surviving skills only.

## [5.0.0] — 2026-05-09

Stable Claude Code plugin baseline v5.0 — final audit green, full KB command support, deprecation closure.

- All 15 v2.5 validators + gates + hooks pass (`validate-plugin.sh` exit 0).
- Final audit: code-graph removal complete, kb-curate/kb-backfill commands added and validated.
- Version bump 4.8.0 → 5.0.0 (major: stable baseline + command completeness).
- PR #79 merged: audit fixes landed.

## [4.8.0] — 2026-05-09

Claude Code-only plugin baseline for building multi-tenant, AI-first software from day zero.

- **Baseline and delivery:** added `docs/BASELINE.md`, `docs/CLAUDE_CODE_DELIVERY.md`, and `tools/validate-plugin.sh` as the operative contract and validation command for installed-plugin and `claude --plugin-dir` usage.
- **Skills consolidation:** added `docs/SKILL_MAP.md`; shortened hot-path skills (`using-agent-skills`, `context-engineering`, `research-first-dev`, `source-driven-development`) and moved long-form material into `references/`.
- **Prior-art-first:** rewrote `research-first-dev` and `rules/core/research-first-citations.md` around evidence packs, local KB, mature OSS, official docs, license risk, and source citations.
- **Tenant-ready design:** added `rules/core/tenant-ready-design.md`; updated implementer, reviewer, tester, and security auditor prompts to enforce profiles/adapters/rules/fixtures and 2+ context coverage.
- **Hook/test contract:** aligned blocking hook tests to Claude Code `exit 2`, changed the edit branch of `pre-edit-intent-gate.sh` to `exit 2`, restored the deprecated code-graph rule, and made legacy code-graph helper scripts executable.
- **Validation:** `bash tools/validate-plugin.sh` passes, covering manifest JSON, skill/agent frontmatter, v2.5 validators, intent gate, authoring gate, hook additions, and `git diff --check`.

## [4.7.0] — 2026-05-08 (this PR)

Read-only Bash fast-path on `pre-edit-intent-gate.sh`. The v4.2 "gate-all-Bash, no allow-list" rule blocked routine exploration (`ls`, `cat`, `git status`, `rg`, `find`) every operator turn — the Bash spawn tax compounded with three other PreToolUse hooks made simple lookups feel sticky. The fast-path lets a curated list of read-only verbs exit 0 immediately while preserving every existing gate behavior for non-read-only commands.

- **`hooks/pre-edit-intent-gate.sh`** — adds a fast-path block in the Bash branch only. Activates when (a) the command contains none of `>`, `;`, `&`, `$`, backtick, AND (b) every pipe-separated segment matches a verb on the allowlist (`ls|cat|grep|rg|find|git status|git diff|gh pr view|...`). Anything that does not match falls through to the existing marker check — no behavioral regression for action commands.
- **Edit/Write branch unchanged.** The fast-path is Bash-only. Implementation files still require an intent marker.
- **Subagent bypass and `BATUTA_INTENT_BYPASS=1` unchanged.** Both still short-circuit before the fast-path block.
- **Plugin version 4.6.0 → 4.7.0.**
- **Intent gate stays `exit 1` (non-blocking warning), not `exit 2` (hard block).** A blanket bump from exit 1 to exit 2 (commit `dfa158f` on origin/main) would reinstall the very friction the read-only fast-path was meant to remove on every non-fast-path Bash. The operator's policy: behavior discipline (writing the `.intent-pending-<ISO>` marker in the same response as the intent JSON, per Step 5 of the v4.6 Intent capture protocol) is the primary mechanism; the hook is a backstop. The other gate hooks (`delegation-guard`, `pr-merge-guard`, `pre-pr-create-guard`, `pre-session-context-gate`) keep `exit 2` — those guard against destructive operations where hard block is the right policy.

Local validation evidence: with the patch applied to `~/.claude/plugins/cache/.../hooks/pre-edit-intent-gate.sh`, `find . -maxdepth 2 -name ".intent-*"` and similar exploratory commands now pass without an intent marker, while non-trivial commands (e.g. anything containing `&&` or a heredoc) continue to require the marker as designed.

Tradeoff acknowledged: a curated allowlist will lag the universe of read-only verbs (no `journalctl`, no `kubectl get`, etc.). Followups can extend the list. The conservative regex (reject any of `>`, `;`, `&`, `$`, backtick) is the safety net — anything fancy falls through.

