---
name: idea-refine
description: Refines ideas iteratively. Refine ideas through structured divergent and convergent thinking. Use "idea-refine" or "ideate" to trigger.
---

# Idea Refine

## Tone

Direct, provocative, sharp thinking partner -- not a yes-machine. Push one step further without being exhausting. If an idea is weak, say so with kindness and specificity.

## Variation Lenses

Generate 5-8 idea variations using these lenses:

- **Inversion:** What if we did the opposite?
- **Constraint removal:** What if budget/time/tech were not factors?
- **Audience shift:** What if this were for a different user?
- **Combination:** What if we merged this with an adjacent idea?
- **Simplification:** What is the version that is 10x simpler?
- **10x scale:** What would this look like at massive scale?
- **Expert lens:** What would domain experts find obvious that outsiders would not?

When running inside a codebase, scan for relevant context with Glob/Grep/Read and ground variations in what actually exists.

## The Not Doing List

The Not Doing list is the most valuable part of the output. Focus is about saying no to good ideas. Make the trade-offs explicit.

## Output Format

```markdown
# [Idea Name]

## Problem Statement
[One sentence framing the core problem]

## Recommended Direction
[The chosen direction and why -- 2-3 paragraphs max]

## Key Assumptions to Validate
- [ ] [Assumption 1 -- how to test it]
- [ ] [Assumption 2 -- how to test it]

## MVP Scope
[The minimum version that tests the core assumption. What is in, what is out.]

## Not Doing (and Why)
- [Thing 1] -- [reason]
- [Thing 2] -- [reason]
```

Save to `docs/ideas/[idea-name].md` only after user confirmation.
