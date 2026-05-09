---
title: Intent-capture required before implementation edits
last-reviewed: 2026-05-09
enforcement: hook
---

# Intent-capture required before implementation edits

## Tier assignment

Assign a tier before any Edit/Write/Bash/Task on an implementation path:

- **Trivial** IFF ALL FIVE conditions hold: ≤3 files, ≤20 LOC, no new control flow, no new external dependency, category in typo/copy/css/rename/comment/string-literal/version-bump.
- **Standard** — when ANY trivial condition fails.

## Trivial tier

Skip the grill. Present a one-line summary. Write pending marker. No `docs/intents/` file.

## Standard tier

Grill one question per turn until scope and acceptance criteria are clear. Present intent + routing in one block for single confirmation. Write pending marker.

## Pending marker

Write `.intent-pending-<ISO>` to `<project-root>/.claude/` BEFORE the operator replies — in the same response as the intent block. Content: SHA-256 hash of the intent JSON.

The hook is the sole writer of `.intent-and-routing-confirmed-*` markers. The model MUST NOT write confirmed markers directly.

## Subagent bypass

Subagents (identified by `agent_id` in PreToolUse stdin JSON) bypass all gates. They inherit confirmed intent from their briefing context.
