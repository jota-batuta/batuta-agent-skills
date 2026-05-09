---
name: code-review-and-quality
description: Conducts multi-axis code review. Use before merging any change. Use when reviewing code written by yourself, another agent, or a human. Use when you need to assess code quality across multiple dimensions before it enters the main branch.
---

# Code Review and Quality

## Mode Detection

Count lines in the diff to determine mode:

- **Quick** (<50 LOC changed, no new files): Correctness + Security + Readability only.
- **Thorough** (>=50 LOC changed, new files, or default): All 5 axes (Correctness, Readability, Architecture, Security, Performance).

Report which mode is active at the start of review output.

## Severity Prefixes

Label every finding so the author knows what is required:

| Prefix | Meaning | Author Action |
|---|---|---|
| **Critical:** | Blocks merge | Security vulnerability, data loss, broken functionality -- must fix |
| *(no prefix)* | Important | Must address before merge |
| **Nit:** | Minor | Author may ignore -- formatting, style preferences |
| **Optional:** / **Consider:** | Suggestion | Worth considering but not required |
| **FYI** | Informational | No action needed -- context for future reference |

## Multi-Model Review Pattern

Use different models for writing vs reviewing to catch blind spots:

```
Model A writes the code
    |
    v
Model B reviews for correctness and architecture
    |
    v
Model A addresses the feedback
    |
    v
Human makes the final call
```

Different models have different blind spots. Cross-model review surfaces issues a single model would miss.
