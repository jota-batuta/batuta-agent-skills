---
name: documentation-and-adrs
description: Records decisions and documentation. Use when making architectural decisions, changing public APIs, shipping features, or when you need to record context that future engineers and agents will need to understand the codebase.
---

# Documentation and ADRs

## Per-Slice Mandate

Update PRD, SPEC, and/or ADR **in the same commit** as the code change. Not after the PR merges, not in a follow-up -- in the same commit.

## ADR Status Lifecycle

`PROPOSED` -> `ACCEPTED` -> `SUPERSEDED` | `DEPRECATED`

Don't delete old ADRs. When a decision changes, write a new ADR that references and supersedes the old one.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The code is the documentation" | Code describes what was built; PRD/SPEC/ADR describes why, what was decided, and what was rejected. Code does not replace decisions. |
| "I'll update the docs after the PR is merged" | After merge, no one remembers the trade-offs. The docs update must happen in the same slice commit. |
| "The SPEC is a draft, I'll formalize it when the feature is done" | The SPEC is the contract. If not updated as you implement, it drifts from code and becomes misleading for the next session. |
