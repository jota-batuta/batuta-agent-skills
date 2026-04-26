# Build Log: global-docs-skeleton — SKILL.md extension

**Date:** 2026-04-25
**Agent:** implementer (Sonnet)
**Slice:** feature/global-docs-skeleton

## Files modified

- `skills/batuta-project-hygiene/SKILL.md`

## Line count

- Before: 292
- After: 372

## Changes made

1. Updated frontmatter `description` to mention "doc skeleton (PRD/SPEC/ADR/plans/sessions)" — final length 198 chars (under 200-char limit).
2. Inserted new **step 4** ("Create project documentation skeleton") between old step 3 (Append Batuta sections) and old step 4 (GitHub boilerplate, now step 5). New step includes:
   - Shell commands to create `docs/`, `docs/adr/`, `docs/plans/active/`, `docs/plans/archive/`, `docs/sessions/` with `.gitkeep` markers.
   - Inline heredoc templates for `docs/PRD.md` (7 sections, <30 lines) and `docs/SPEC.md` (<30 lines).
   - Inline heredoc template for `docs/adr/0001-template-decision.md` (<40 lines).
3. Renumbered old step 4 → step 5 (GitHub boilerplate), old step 5 → step 6 (Verification).
4. Updated step 6 verification checks to include `test -f docs/PRD.md`, `test -f docs/SPEC.md`, `test -f docs/adr/0001-template-decision.md`, and directory checks.
5. Updated bottom `## Verification / After project-init` block with the same additional checks.
6. `Mode: feature-init` flow untouched.

## Deviations from prompt

### BLOCKER (non-escalated, documented): 150-line constraint

The prompt states "DO NOT exceed 150 lines total in the SKILL.md file (current is 292 — that means the existing content needs to stay roughly as is and your additions need to be tight)."

This constraint is self-contradictory: the file was already 292 lines before any edits, and the prompt explicitly prohibits removing existing content. The additions (new step 4, updated verification blocks, updated frontmatter) added ~80 lines, bringing the total to 372.

**Decision:** Proceed with the additions, document the overrun here, and flag for main-agent review. Removing existing content to hit 150 lines would require lossy edits that violate the "do not remove existing content" constraint. The 150-line target appears to be an error in the prompt (it would require the file to already be ≤110 lines to accommodate 40 new lines).

**Escalation status:** Documented — not a hard blocker for the implementation itself. Main agent should acknowledge and update the constraint if 150 lines was a typo for 400 or similar.

## Verification

- YAML frontmatter: VALID (name + description present, description = 198 chars)
- Line count: 372
- Mode: feature-init: untouched (verified by inspection)
