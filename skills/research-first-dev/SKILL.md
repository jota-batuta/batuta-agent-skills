---
name: research-first-dev
description: Enforces prior-art-first development. Use before building with external libraries, APIs, CLIs, or reusable patterns; find proven work, adapt it, cite it, and test it across contexts.
---

# Research First Dev

## Overview

Research-first means prior-art-first: check whether somebody already solved the
problem, copy or adapt the proven approach, and invent only when no reliable
option exists. The output is an evidence pack: source, version/context, chosen
approach, rejected alternatives, license risk, and verification plan.

This skill delegates library lookup mechanics to `skills/_vendored/context7/`.
For source-driven legacy prompts, route here.

## When to Use

Trigger before:

- Writing `import`, `require`, `from ... import`, `use`, SDK calls, HTTP API
  calls, or CLI invocations not verified in this session.
- Adding reusable architecture, adapters, generators, rules, or tenant/context
  variation logic.
- Copying code from open source or adapting a pattern from another project.
- Answering whether a library, API, or mature project supports a behavior.

Do not use for language built-ins, typo-only edits, or code already cited in the
same session and version.

## Process

### Step 1: Resolve version and context

Read manifests and local config first: `package.json`, `pyproject.toml`,
`requirements.txt`, `Cargo.toml`, `go.mod`, lockfiles, CLI version output, or
API version docs. Record version, tenant/context, runtime, and constraints.

### Step 1.5: Local KB lookup

Before going external, check the operator vault. Resolve `vault_root` from
`.claude/kb-config.json` or `$VAULT_ROOT`; if unreachable, skip Step 1.5 and
proceed to Step 2.

Lookup order is **priority L2 > L3 > L1**:

1. L2 curated: `<vault_root>/decisions`, `gotchas`, `playbooks`, and project
   curated folders. Prefer entries with `related:` wikilinks and fresh
   `last_verified`.
2. L3 glossary: product/domain glossary entries that identify known integration
   surfaces.
3. L1 journals: session captures only. Treat as `no curado, verifica` and always
   run Step 2.

Staleness policy by `last_verified`: `< 4 meses` can win locally; `4-12 meses`
requires Step 2 and a dual cite; `> 12 meses` informs context only and requires
Step 2. Always run Step 2 for new libraries, major bumps, structural decisions,
or anything where local KB cannot substitute current source verification.

Local citation formats:

```ts
// Source: ~/batuta-kb/gotchas/example.md (verified 2026-03-15)
// Cross-checked: https://docs.example.com/api (verified 2026-05-09, lib@1.2.3)
```

A `Source: ~/batuta-kb/...` line with no `Cross-checked:` is local-only and only
valid for fresh curated L2/L3 entries.

### Step 2: External prior-art lookup

Use Context7 first for libraries/frameworks:

```text
/mcp context7 resolve-library-id "<library-name>"
/mcp context7 get-library-docs "<resolved-id>" --topic "<specific-api>"
```

If Context7 lacks coverage, use official docs, release notes, source repos, or
mature open-source implementations. Prefer copied/adapted prior art over new
logic. Reject AI summaries and stale blog/forum answers as primary sources.

### Step 3: Select and adapt

Build a short evidence pack:

- Source chosen: URL/path, version, license if copying code.
- What is copied, adapted, or rejected.
- Why it fits this repo's tenant/context boundaries.
- Tests required across at least two contexts when behavior varies by tenant,
  bank, environment, provider, format, rule, or period.

### Step 4: Cite at the import or decision site

Every new external import/call site gets a nearby `Source:` comment:

```ts
// Source: https://orm.drizzle.team/docs/select (verified 2026-05-09, drizzle@0.32.1)
import { eq } from "drizzle-orm";
```

For copied/adapted open-source code, cite the repository, commit/tag, license,
and files adapted in a doc comment or decision record.

## Anti-Rationalizations

| Excuse | Reality |
|---|---|
| "We can invent faster" | Unverified invention is slower after review and production fixes. |
| "The API is stable" | Stable APIs still change by version; cite current evidence. |
| "I found a blog" | Blogs can inform search, not serve as primary proof. |
| "Only one tenant exists today" | Variability is still context; prove at least two representative contexts. |

## Red Flags

- New import or API call without a `Source:` citation.
- Hardcoded client, bank, provider, environment, or format in core logic.
- No license note when adapting open-source code.
- Evidence pack lacks rejected alternatives.
- Tests cover only one context when behavior is context-dependent.

## Verification

- Evidence pack exists in the response, build-log, or decision doc.
- Versions match dependency manifests or API docs.
- `Source:` citations exist for every new external import/call.
- Copied/adapted code records source and license.
- Context-dependent behavior is tested with at least two fixtures/profiles.
