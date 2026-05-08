# Changelog — batuta-agent-skills

All notable changes to this plugin are listed here.

## [4.7.0] — 2026-05-08 (this PR)

Read-only Bash fast-path on `pre-edit-intent-gate.sh`. The v4.2 "gate-all-Bash, no allow-list" rule blocked routine exploration (`ls`, `cat`, `git status`, `rg`, `find`) every operator turn — the Bash spawn tax compounded with three other PreToolUse hooks made simple lookups feel sticky. The fast-path lets a curated list of read-only verbs exit 0 immediately while preserving every existing gate behavior for non-read-only commands.

- **`hooks/pre-edit-intent-gate.sh`** — adds a fast-path block in the Bash branch only. Activates when (a) the command contains none of `>`, `;`, `&`, `$`, backtick, AND (b) every pipe-separated segment matches a verb on the allowlist (`ls|cat|grep|rg|find|git status|git diff|gh pr view|...`). Anything that does not match falls through to the existing marker check — no behavioral regression for action commands.
- **Edit/Write branch unchanged.** The fast-path is Bash-only. Implementation files still require an intent marker.
- **Subagent bypass and `BATUTA_INTENT_BYPASS=1` unchanged.** Both still short-circuit before the fast-path block.
- **Plugin version 4.6.0 → 4.7.0.**
- **Intent gate stays `exit 1` (non-blocking warning), not `exit 2` (hard block).** A blanket bump from exit 1 to exit 2 (commit `dfa158f` on origin/main) would reinstall the very friction the read-only fast-path was meant to remove on every non-fast-path Bash. The operator's policy: behavior discipline (writing the `.intent-pending-<ISO>` marker in the same response as the intent JSON, per Step 5 of the v4.6 Intent capture protocol) is the primary mechanism; the hook is a backstop. The other gate hooks (`delegation-guard`, `pr-merge-guard`, `pre-pr-create-guard`, `pre-session-context-gate`) keep `exit 2` — those guard against destructive operations where hard block is the right policy.

Local validation evidence: with the patch applied to `~/.claude/plugins/cache/.../hooks/pre-edit-intent-gate.sh`, `find . -maxdepth 2 -name ".intent-*"` and similar exploratory commands now pass without an intent marker, while non-trivial commands (e.g. anything containing `&&` or a heredoc) continue to require the marker as designed.

Tradeoff acknowledged: a curated allowlist will lag the universe of read-only verbs (no `journalctl`, no `kubectl get`, etc.). Followups can extend the list. The conservative regex (reject any of `>`, `;`, `&`, `$`, backtick) is the safety net — anything fancy falls through.

