# Build log — intent-gate-per-turn (v4.2)

**Date**: 2026-05-04
**Implementer**: generic-implementer (claude-sonnet-4-6)
**Slice**: `docs/plans/active/2026-05-04-intent-gate-per-turn.md`

## Files modified

- `hooks/clear-intent-marker.sh` — CREATED. UserPromptSubmit hook that deletes all `.intent-confirmed-*` markers at the start of each operator turn. Fail-soft (exit 0 always).
- `hooks/pre-edit-intent-gate.sh` — REPLACED. v4.2 rewrite: adds Bash branch (gate-all-Bash, no allow/deny list) and removes `-mmin -60` time window. Marker existence check only.
- `hooks/hooks.json` — MODIFIED. Added `UserPromptSubmit` entry pointing to `clear-intent-marker.sh`; added `pre-edit-intent-gate.sh` to the existing `Bash` PreToolUse matcher (after `pr-merge-guard.sh`).

## Tasks completed (mapped to plan)

- Task 1 (NEW `hooks/clear-intent-marker.sh`): complete.
- Task 2 (MODIFY `hooks/pre-edit-intent-gate.sh`): complete — Bash branch added, -mmin window removed, subagent bypass and path-traversal guard preserved.
- Task 3 (MODIFY `hooks/hooks.json`): complete — UserPromptSubmit + Bash intent-gate added.

## Libraries researched

- Claude Code hooks API: https://docs.claude.com/en/docs/claude-code/hooks (verified 2026-05-04, Claude Code 2.x). No external dependencies introduced — pure bash + jq (already present in prior hooks).

## Non-obvious decisions

1. **`set +e` in `clear-intent-marker.sh` vs `set -uo pipefail` in `pre-edit-intent-gate.sh`**: The cleanup hook (UserPromptSubmit) is fail-soft by design — it must never block a session. The gate hook (PreToolUse) uses strict error handling because a silent failure there would silently permit ungated edits, which is the worse failure mode.

2. **`shopt -s nullglob` pattern in `clear-intent-marker.sh`**: Needed so the glob `"$marker_dir"/.intent-confirmed-*` expands to an empty array rather than a literal string when no markers exist. Without nullglob, `rm -f` would receive the literal pattern as its argument.

3. **Bash branch placed before Edit/Write branch in `pre-edit-intent-gate.sh`**: The Bash path skips file_path extraction and exempt-path checking entirely — those are meaningless for shell commands. Keeping the branches fully independent avoids cross-contamination.

4. **`pr-merge-guard.sh` before `pre-edit-intent-gate.sh` in Bash matcher**: Preserves the existing order from the plan — pr-merge check fires first as it's the more specific block (prevents merges to main); intent-gate fires second as the broader policy gate.

5. **No `find_project_root_and_marker` helper used in Bash branch**: The helper function is defined but the Bash branch uses an inline resolution to keep the control flow local and readable. The function is available for future use if more branches are added.

## Deviations from plan

None. All 3 file changes implemented exactly as specified in the plan's "Archivos a modificar" section. Tasks 4–7 of the plan (SKILL.md, rules, CLAUDE.md, global CLAUDE.md) are out of scope for this slice as delegated — the implementer task covered only files under `hooks/`.

## Edge cases handled

- No `.git/` found during walk-up: fail-soft allow (exit 0) in both hooks.
- `jq` not installed: `pre-edit-intent-gate.sh` exits 0 with a warning (same pattern as v4.1).
- Zero markers to delete: `clear-intent-marker.sh` skips `rm` call entirely (nullglob array length check).
- `CLAUDE_PROJECT_DIR` with Windows backslash path: backslash-to-slash normalization present in `pre-edit-intent-gate.sh` Bash branch via `${CLAUDE_PROJECT_DIR:-}` (inherits the same treatment as the Edit/Write branch).

## Security notes

- CWE-22 (path traversal): the `..` guard in the Edit/Write branch is preserved unchanged from v4.1. The Bash branch has no file_path to guard — it gates on tool name alone.
- CWE-732 (incorrect permission assignment): `clear-intent-marker.sh` is chmod +x (0755 effective). Log writes go to `.claude/kb-debug.log` in the project root, same location as all other hook logs — no new write surfaces introduced.
- The `BATUTA_INTENT_BYPASS=1` bypass is operator-side only; cannot be set from inside an agent tool call.

## Verification results

1. `bash -n hooks/clear-intent-marker.sh` → SYNTAX OK
2. `bash -n hooks/pre-edit-intent-gate.sh` → SYNTAX OK
3. `python3 -c "import json; json.load(open('hooks/hooks.json'))"` → JSON OK
4. `ls -la hooks/clear-intent-marker.sh` → `-rwxrwxrwx` (executable)
5. `git status --short` after staging → exactly 3 files in index, no unexpected additions

## v4.3 amendment (2026-05-04)

**Task**: Replace `hooks/clear-intent-marker.sh` with v4.3 — adds Part 2 (JSON `additionalContext` injection via `hookSpecificOutput`) to the existing Part 1 (marker invalidation, preserved verbatim from v4.2).

**Libraries researched**: Claude Code hooks `hookSpecificOutput.additionalContext` protocol — https://docs.claude.com/en/docs/claude-code/hooks (verified 2026-05-04, Claude Code 2.x). `jq -n --arg` pattern used for safe string embedding (avoids manual JSON escaping). `python3` fallback used when `jq` is absent — same pattern as prior hooks.

**Non-obvious decisions**:
- `jq -n --arg ctx "$reminder"` chosen over here-doc interpolation: `--arg` handles all shell-special chars and newlines without escaping. The `python3` fallback passes the reminder via `REMINDER` env var (same reason — avoids shell quoting issues in the `-c` string).
- `trap 'exit 0' ERR` at top of script ensures both Part 1 and Part 2 are fail-soft. If `jq` or `python3` produce non-zero exit codes, the trap catches it and exits 0 — session never blocked.
- No JSON emitted when neither `jq` nor `python3` is available. The hook exits 0 silently; the reminder is skipped as a best-effort feature, consistent with the fail-soft contract.

**Verification results (v4.3)**:
1. `bash -n hooks/clear-intent-marker.sh` → SYNTAX OK
2. `ls -la hooks/clear-intent-marker.sh` → `-rwxrwxrwx` (executable bit present)
3. `echo '{}' | bash hooks/clear-intent-marker.sh | python3 -m json.tool` → valid JSON with `hookSpecificOutput.additionalContext` containing the full reminder string

## Open questions for auditors

- Q1 (test-engineer): Is there a test covering the `clear-intent-marker.sh` fail-soft path (no `.git/` found, no `.claude/` dir)? Recommend adding to `tests/` if the test harness covers hooks.
- Q2 (code-reviewer): The `find_project_root_and_marker` helper in `pre-edit-intent-gate.sh` is defined but only referenced conceptually — the Bash branch and Edit/Write branch both inline their resolution. If a 4th branch is ever added, the helper reduces duplication. Acceptable as-is for now, but flag if the inline pattern becomes inconsistent.
- Q3 (security-auditor): The Bash gate has no exempt list. This means `git status`, `ls`, `echo` etc. are all gated. This was an explicit operator decision ("gate-all-Bash, no allow-list"). Confirm the business rationale is documented satisfactorily in the hook header comments and rule file (rules/core/intent-capture-required.md update is out of scope for this slice).
