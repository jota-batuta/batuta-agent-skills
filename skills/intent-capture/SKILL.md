---
name: intent-capture
description: Use when the operator describes any concrete work to execute — edits, writes, commands, or changes to files, repos, or configs.
---

# intent-capture

The agent NEVER executes work before capturing a confirmed intent.

## Tier Assignment

Assign `tier: "trivial"` if and only if **ALL FIVE** hold:

1. ≤ 3 files touched
2. ≤ 20 LOC changed
3. No new control flow (`if` / `for` / `while` / `try` / `async`)
4. No new external dependency
5. Category in: typo, copy, css, rename, comment, string-literal, version-bump

Any condition fails -> `tier: "standard"`.

## Trivial Tier

- Skip the grill.
- Display a one-line summary: `Trivial tier -- {category}: {refined_text}. Files: {paths}. Routing: main-direct.`
- Write the pending marker (see below).
- No `docs/intents/` file.

## Branch Guard (standard tier only)

Before grilling, check `git branch --show-current`. If `main` (or `master`), create a feature branch:

```bash
git checkout -b feat/<slug-from-first-ask>
```

If already on a `feat/*` branch, skip — one branch per session, not per intent.

## Standard Tier

Ask **one concrete question per turn** until all three are clear for each ask:

- **text** -- what exactly
- **scope** -- where it applies, where it does not
- **acceptance** -- how to verify it is done

Before asking the operator, check the codebase. If vault, ADRs, or source files answer the question, cite the evidence instead of asking.

Once clear, present intent + routing in **one block**. Single confirmation covers both.

## Marker Write

On confirmation, write `<project-root>/.claude/.intent-pending-<ISO-timestamp>` (UTC, RFC 3339). Content: SHA-256 hash of the confirmed intent. Gitignored. The `clear-intent-marker.sh` hook promotes this to `.intent-and-routing-confirmed-<ISO>` on the operator's next confirmation message. Execution gates block `Bash`/`Edit`/`Write` until promoted.

Trivial tier: marker is required (skips grill and docs file, NOT the marker).
