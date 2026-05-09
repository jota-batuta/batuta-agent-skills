---
name: research-first-dev
description: Enforces prior-art-first development. Use before building with external libraries, APIs, CLIs, or reusable patterns; find proven work, adapt it, cite it, and test it across contexts.
---

# Research First Dev

## 6-Layer Harness Mandate

For AI agent projects, define the 6-layer harness BEFORE choosing any framework:

1. **Multi-tenant Domain Connectors** -- one connector per domain
2. **Rules-as-Code** -- versioned, testable business rules
3. **Memory Architecture** -- tenant-scoped, replayable
4. **Durable Orchestration** -- Temporal.io (workflows, dual-mode, HITL, Event History)
5. **Observability** -- Langfuse + 14 audit fields, confidence, drift, explainability
6. **Agent Heartbeat & Execution Autonomy** -- prompt-based vs autonomous unattended

The harness is the durable asset; frameworks and models are replaceable. Only after the harness is documented, proceed to framework evaluation.

## KB Lookup Order

Priority: **L2 curated > L3 glossary > L1 journals**.

- L2: `<vault_root>/decisions`, `gotchas`, `playbooks`. Prefer entries with fresh `last_verified`.
- L3: product/domain glossary for known integration surfaces.
- L1: session captures only. Treat as unverified -- always cross-check externally.

Staleness: `< 6 months` = trustworthy locally. `> 6 months` = stale, requires external verification.

## Citation Format

```
// Source: <url-or-path> (verified YYYY-MM-DD, lib@version)
```

Every new external import/call site gets a nearby `Source:` comment.

## No Prior Art Found

If no reliable prior art exists, label the code as invented and add tests that cover at least the claimed behavior.
