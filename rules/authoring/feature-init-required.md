---
title: Feature-init workflow required before creating feature CLAUDE.md
applies-to: ["markdown", "batuta-plugin"]
last-reviewed: 2026-05-09
enforcement: hook
hook: hooks/pre-write-feature-gate.sh
---

# Feature-init workflow required before creating feature CLAUDE.md

Orphan feature docs are the failure mode this rule prevents. A feature CLAUDE.md created without the `batuta-project-hygiene` workflow lands in the repo without layout detection, without a matching SPEC, and without the scaffold commit that ties the feature into the project's structure. The result is a CLAUDE.md that drifts from the codebase it describes because it was never anchored to it. The `pre-write-feature-gate.sh` hook blocks creation of any subdirectory CLAUDE.md until the feature-init workflow has run end-to-end and written a fresh marker.

This rule is derived from the operator's global `~/.claude/CLAUDE.md` "Authoring gates" section and the project-level CLAUDE.md "Mandatory Skills" declaration. It counts as universally applied under §A.6 of the admission gate.

## Inviolable rules

1. Before any `Write` or `Edit` that creates a new `**/CLAUDE.md` file in a subdirectory (not the project root), the agent (main or subagent) MUST first invoke `batuta-project-hygiene` with `mode=feature-init` and complete its workflow end-to-end (Steps 1-5: layout detection, CLAUDE.md generation, SPEC creation, scaffold commit).
2. Completion of `batuta-project-hygiene` Step 5.5 MUST leave a marker file at `<project-root>/.claude/.authoring-marker-feature-<ISO-timestamp>` (UTC, RFC 3339 format). The marker is the proof-of-workflow consumed by the runtime hook `pre-write-feature-gate.sh`.
3. The marker is valid for 60 minutes from its filesystem mtime. Any `Write` that creates a new feature CLAUDE.md after the marker expires MUST re-invoke `batuta-project-hygiene`.
4. Editing an existing feature CLAUDE.md is NOT subject to this gate — only creation of a new CLAUDE.md (file does not yet exist on disk) requires the marker. The hook implements the file-existence check as the boundary.
5. The root CLAUDE.md (`CLAUDE.md` or `./CLAUDE.md` at the project root) is NOT subject to this gate. Only subdirectory CLAUDE.md files are gated.
6. No repo-scope guard — unlike the skill and agent authoring gates, this gate is cross-project by design. It fires in any repository, not just the `batuta-agent-skills` plugin repo. Projects that do not want the gate must opt out via `BATUTA_FEATURE_INIT_BYPASS=1`.

## Allowed patterns

```bash
# Operator creating a new feature CLAUDE.md — proper sequence
$ claude
> /skill batuta-project-hygiene
# (mode=feature-init <feature-name>)
# (workflow runs: layout detection → CLAUDE.md → SPEC → scaffold commit)
# (Step 5.5 writes marker: .claude/.authoring-marker-feature-2026-05-09T14:30:00Z)

> Now create src/auth/CLAUDE.md with the validated content
# (Write proceeds; hook finds recent marker; marker is <60 min old; allowed)
```

```markdown
<!-- Editing an existing feature CLAUDE.md is unrestricted -->
<!-- File: src/auth/CLAUDE.md (already exists on disk) -->
# auth — minor update to the API section — no marker required
```

```bash
# Root CLAUDE.md is unrestricted — no marker needed
> Write CLAUDE.md with the updated project overview
# (hook detects root-level path → exits with allow)
```

```bash
# Operator-side bypass for legitimate retrofits
$ BATUTA_FEATURE_INIT_BYPASS=1 claude
# All feature CLAUDE.md creation allowed without marker.
# Bypass is logged to .claude/kb-debug.log for audit.
> Write src/legacy-module/CLAUDE.md
# (allowed — bypass active)
```

## Anti-patterns

```bash
# Bad — violates rule 1 (creating feature CLAUDE.md without running feature-init)
$ claude
> Create src/payments/CLAUDE.md with the content I described
# Hook blocks: "RULE violated (feature-init gate): cannot create feature CLAUDE.md at:
#   src/payments/CLAUDE.md"
# No fresh marker at .claude/.authoring-marker-feature-*
```

```bash
# Bad — violates rule 2 (workflow interrupted before marker is written)
$ claude
> /skill batuta-project-hygiene
# (operator interrupts the skill at Step 3, before Step 5.5 writes the marker)
> Create src/payments/CLAUDE.md
# Hook blocks: marker file missing because workflow did not finish
```

```bash
# Bad — violates rule 3 (marker expired)
# Marker mtime: 2026-05-09T12:00:00Z
# Current time:  2026-05-09T14:30:00Z (150 min elapsed)
> Create src/notifications/CLAUDE.md
# Hook blocks: marker exists but mtime is older than 60 minutes
```

## Documented exceptions

- **`BATUTA_FEATURE_INIT_BYPASS=1`**: operator-side environment variable, set on the shell that launches Claude Code. Intended for retroactively adding feature CLAUDE.md files to existing codebases where running the full feature-init workflow would be disproportionate. The bypass logs a warning to `.claude/kb-debug.log` for audit. Cannot be set from inside an agent's tool call — the design prevents the agent from bypassing its own gate.
- **Subagent bypass**: when the hook detects a non-empty `agent_id` in the PreToolUse JSON input, it allows the call unconditionally. Subagents inherit confirmed intent from the main agent that delegated the work. This prevents subagent-driven scaffolding workflows from deadlocking on a gate the main agent already satisfied.
- **Missing jq**: if `jq` is not installed, the hook cannot parse the PreToolUse JSON input. It falls back to permissive mode (exit 0) with a warning on stderr. This is a fail-soft design consistent with all other Batuta hooks.
- **No project root**: if the hook cannot determine the project root (no `CLAUDE_PROJECT_DIR`, no `.git/` directory found), it allows the call. Files outside a git repository are not subject to feature-init gating.
