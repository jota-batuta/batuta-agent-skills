---
name: source-driven-development
description: Compatibility wrapper for source-cited implementation. Use research-first-dev for the active prior-art-first process before writing framework or library code.
---

# Source-Driven Development

## Overview

This skill is now a compatibility wrapper. The active workflow is
`research-first-dev`, which implements prior-art-first development: find a proven
solution first, adapt it, cite the source, and only invent when no reliable prior
art exists.

Long-form source-citation examples are archived in
`references/source-driven-development-playbook.md`.

## When to Use

- A prompt, doc, or habit still says `source-driven-development`.
- The task involves framework, library, CLI, or API behavior that may vary by
  version.
- You are reviewing code and need to confirm that a pattern has an authoritative
  source.

## Process

1. Route immediately to `research-first-dev`.
2. Read dependency manifests before trusting any API shape.
3. Prefer internal KB, existing project code, mature open source, official docs,
   changelogs, and release notes in that order.
4. Cite the selected source at the import/call site or in the decision record.
5. If no trustworthy source exists, mark the implementation as invented and add
   tests that cover at least the claimed behavior.

## Allowed Sources

| Priority | Source |
|---|---|
| 1 | Curated Batuta KB entry with fresh `last_verified` |
| 2 | Existing project code with matching version/context |
| 3 | Mature open-source implementation with compatible license |
| 4 | Official docs, changelog, release notes, or source repository |
| 5 | Web standards references such as MDN or WHATWG |

## Anti-Rationalizations

| Excuse | Reality |
|---|---|
| "I know this API" | Memory is not evidence; cite a current source. |
| "This wrapper is enough" | The wrapper only routes; `research-first-dev` owns the gate. |
| "Docs are missing" | Missing docs is evidence; adapt prior art or flag invention. |

## Verification

- `research-first-dev` was invoked for the actual lookup.
- The selected source is recorded with URL/path, version, and verification date.
- Framework/library code contains a nearby `Source:` citation.
- Unverified inventions are called out and covered by tests.
