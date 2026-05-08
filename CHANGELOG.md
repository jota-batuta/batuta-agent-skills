# Changelog — batuta-agent-skills

All notable changes to this plugin are listed here.

## [4.7.0] — 2026-05-08 (this PR)

Read-only Bash fast-path on `pre-edit-intent-gate.sh`. The v4.2 "gate-all-Bash, no allow-list" rule blocked routine exploration (`ls`, `cat`, `git status`, `rg`, `find`) every operator turn — the Bash spawn tax compounded with three other PreToolUse hooks made simple lookups feel sticky. The fast-path lets a curated list of read-only verbs exit 0 immediately while preserving every existing gate behavior for non-read-only commands.

- **`hooks/pre-edit-intent-gate.sh`** — adds a fast-path block in the Bash branch only. Activates when (a) the command contains none of `>`, `;`, `&`, `$`, backtick, AND (b) every pipe-separated segment matches a verb on the allowlist (`ls|cat|grep|rg|find|git status|git diff|gh pr view|...`). Anything that does not match falls through to the existing marker check — no behavioral regression for action commands.
- **Edit/Write branch unchanged.** The fast-path is Bash-only. Implementation files still require an intent marker.
- **Subagent bypass and `BATUTA_INTENT_BYPASS=1` unchanged.** Both still short-circuit before the fast-path block.
- **Plugin version 4.6.0 → 4.7.0.**

Local validation evidence: with the patch applied to `~/.claude/plugins/cache/.../hooks/pre-edit-intent-gate.sh`, `find . -maxdepth 2 -name ".intent-*"` and similar exploratory commands now pass without an intent marker, while non-trivial commands (e.g. anything containing `&&` or a heredoc) continue to require the marker as designed.

Tradeoff acknowledged: a curated allowlist will lag the universe of read-only verbs (no `journalctl`, no `kubectl get`, etc.). Followups can extend the list. The conservative regex (reject any of `>`, `;`, `&`, `$`, backtick) is the safety net — anything fancy falls through.

