---
name: living-docs-maintenance
description: Use at the end of every implementation slice to revisit, update, and record evidence in PRD, SPEC, and ADR. PRD is the living implementation sheet.
---

# Living Docs Maintenance

## Overview

PRD, SPEC, and ADR are living documents, not static text. This skill ensures that after every slice the operator and future agents see the current truth.

## When to Use

- End of every `incremental-implementation` slice (after tests pass and before audit chain).
- After any architectural decision during `spec-driven-development`.
- When `code-reviewer` or `security-auditor` flags "living docs not updated".

## Process

1. **Re-read relevant sections**
   - PRD: acceptance criteria and "why" for the current feature.
   - SPEC: architecture decisions and data model for the modules touched.
   - ADR: the most recent decision record related to this slice.

2. **Update PRD (implementation sheet)**
   - Mark completed acceptance criteria with `[x]` and date.
   - Add new criteria discovered during implementation.
   - Note any deviation from original scope with rationale.

3. **Update SPEC (as-built)**
   - Record actual interfaces, types, and module boundaries that were implemented.
   - Add sequence diagrams or pseudocode only if they changed from the planned version.

4. **Update or create ADR**
   - If a significant trade-off, rejected alternative, or new constraint was discovered, append a new ADR entry (or update the existing one).
   - Format: Context → Decision → Consequences (with rejected alternatives and cost/risk).

5. **Write evidence**
   - Add a one-line note in the slice commit message or in `docs/intents/<id>.md`:
     "Living docs updated: PRD §3.2 marked complete, ADR-0017 created for X vs Y trade-off."

## Verification

Before handing off to the audit chain, confirm:
- PRD has at least one checkbox updated in this slice.
- SPEC or ADR has a new or modified section dated today.
- The change is visible in `git diff --staged` for the docs/ files.

If any check fails, the slice is not ready for `code-reviewer`.