# user-settings

Backup of user-level Claude Code configuration for `jota-batuta`. Stored in this repo so the canonical rules survive machine changes and can be reviewed alongside the skills they reference.

## What lives here

| Backup file | Real location | Purpose |
|---|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | User-global rules loaded into every Claude Code session (research-first, divergent thinking, PR policy, language policy, authoring gates, intent-capture, native-delegation routing, autonomous project hygiene) |
| `MEMORY.md` + `memory/*.md` | (see "Memory in Claude Code 2.1.x" below) | Two reusable memory entries that haven't been absorbed into `CLAUDE.md` |

## Memory in Claude Code 2.1.x

**Important context for fresh-machine installs.** In Claude Code 2.1.x, auto-memory moved from a single user-level path to **per-project** directories:

| Claude Code version | Memory location |
|---|---|
| 1.x | `~/.claude/MEMORY.md` + `~/.claude/memory/*.md` (single user-level set) |
| **2.1.x** (current) | `~/.claude/projects/<project>/memory/MEMORY.md` + `~/.claude/projects/<project>/memory/*.md` (one set per project the operator opens) |

This backup directory was originally designed for the 1.x model. The two retained entries (`feedback_sanitize_public_repos`, `reference_external_docs`) are still valuable but are no longer auto-loaded by Claude Code from this path. Treat them as **portable reference material** to copy into a project's memory directory or absorb into a project's `CLAUDE.md` when relevant.

The five other entries that used to live here have been removed (see `MEMORY.md` for the rationale per entry); their content is either now in `CLAUDE.md` or stale post-WSL-migration / post-v2.7.

## How to restore on a new machine

```bash
# CLAUDE.md (user-global rules — the high-value restore)
cp user-settings/CLAUDE.md ~/.claude/CLAUDE.md
```

That's the canonical restore step. After it, open Claude Code and the user-level rules load automatically on the next session.

The reusable memory entries can be applied to a specific project as needed:

```bash
# Optional — copy the two retained memory entries into a project's auto-memory dir
PROJECT_MEMORY=~/.claude/projects/<project-slug>/memory
mkdir -p "$PROJECT_MEMORY"
cp user-settings/memory/feedback_sanitize_public_repos.md "$PROJECT_MEMORY/"
cp user-settings/memory/reference_external_docs.md "$PROJECT_MEMORY/"
# Then add the matching index lines to "$PROJECT_MEMORY/MEMORY.md"
```

## How to keep CLAUDE.md in sync

Sync is **manual**. When `~/.claude/CLAUDE.md` changes on any machine:

```bash
cp ~/.claude/CLAUDE.md user-settings/CLAUDE.md
git add user-settings/CLAUDE.md
git commit -m "chore(user-settings): sync CLAUDE.md"
git push
```

Symptom of drift: a rule referenced elsewhere in the plugin (e.g. an ADR or a session journal) doesn't match the wording in `user-settings/CLAUDE.md`. Fix: re-run the sync block above.

## Scope

User-level configuration — things that apply to every project on every machine the operator uses.

- **Project-specific rules** live in each project's own `./CLAUDE.md` and never here.
- **Project-specific auto-memory** lives in `~/.claude/projects/<project>/memory/` (Claude Code 2.1.x) — that is project-scoped state, NOT backed up here.
- **Plugin-shipped rules** live in `<plugin>/rules/` and have their own `_meta/how-to-import.md` consumer protocol.

## Sanitization commitment

This folder is committed to a PUBLIC repo (`jota-batuta/batuta-agent-skills`). Memory entries here MUST be sanitized of:

- Specific Batuta client names
- Specific CO-vendor names that imply a commercial relationship (DIAN, Bancolombia, BBVA, Bold)
- Specific internal project names with sensitive context

The retained memory entry `feedback_sanitize_public_repos.md` documents the rule. Before any commit to this folder, grep the diff for client/vendor names and abstract them.

## When to NOT back up here

- Anything that contains an actual secret (`.env` content, API keys, tokens) — those NEVER go in any committed file regardless of repo visibility.
- Per-project auto-memory (`~/.claude/projects/<project>/memory/`) — project-scoped, not user-level.
- Single-machine state that does not survive machine changes (session locks, scheduled-task state, plugin install caches under `~/.claude/plugins/cache/`).
