# ADR Transition Index

**Status:** transition index
**Baseline:** [`../BASELINE.md`](../BASELINE.md)
**Last reviewed:** 2026-05-08

ADRs remain historical records and are not deleted. This index tells readers which decisions still define the current Claude Code plugin baseline, which have been absorbed into the baseline, and which document deprecated implementations.

## Current Baseline

These ADRs still describe active parts of the Claude Code plugin contract.

| ADR | Status |
|---|---|
| [0001 — Rule zero delegation-only main](0001-rule-zero-delegation-only-main.md) | Current: main agent as architectural seat, implementation delegated. |
| [0002 — Implementer Haiku separate agent](0002-implementer-haiku-separate-agent.md) | Current: trivial implementation lane remains distinct. |
| [0003 — Plugin-level hook vs permissions deny](0003-plugin-level-hook-vs-permissions-deny.md) | Current: Claude Code hooks remain the enforcement surface. |
| [0004 — Audit chain sequential, not parallel](0004-audit-chain-sequential-not-parallel.md) | Current: test -> review -> security remains the audit order. |
| [0005 — Plan-mode persistence mechanism](0005-plan-mode-persistence-mechanism.md) | Current: active plans and `/save-plan` remain part of the session handoff. |
| [0006 — Trust native delegation](0006-trust-native-delegation.md) | Current: hooks enforce hard constraints; Claude Code handles delegation judgment. |
| [0009 — E2E print-mode methodology](0009-e2e-print-mode-methodology.md) | Current: `--plugin-dir` is the supported clone-repo validation path. |
| [0010 — PR merge guard](0010-pr-merge-guard-env-var-opt-in.md) | Current: PR merges remain operator-owned. |
| [0011 — Automatic persistence and curation](0011-automatic-persistence-and-curation.md) | Current: commit/session persistence and authoring gates remain part of the KB flow. |
| [0012 — Obsidian-only KB pipeline](0012-obsidian-only-kb-pipeline.md) | Current: Obsidian is the operational memory. |
| [0015 — Two-phase intent marker protocol](0015-v4.6-two-phase-intent-marker.md) | Current: intent marker lifecycle is part of the Claude Code contract. |
| [0016 — Audit gap closure](0016-audit-gap-closure.md) | Current: hook/command enforcement gaps are part of the active hardening path. |

## Superseded By Baseline

These ADRs remain accepted history, but day-to-day readers should follow [`../BASELINE.md`](../BASELINE.md) first.

| ADR | Status |
|---|---|
| [0013 — v4.0 distillation](0013-v4.0-distillation.md) | Superseded by baseline as the current entry point; its pruning rationale remains useful history. |
| [0014 — v4.5 intent-capture slim-down](0014-v4.5-intent-capture-slim.md) | Superseded by the v4.6 marker protocol and the baseline's hook/intent contract. |

## Deprecated Implementation

These ADRs describe mechanisms that are no longer active baseline behavior.

| ADR | Status |
|---|---|
| [0007 — Code knowledge graph dual engine](0007-code-graph-dual-engine.md) | Deprecated: graphify was removed and `code-graph` is no longer active baseline. |
| [0008 — Audit chain consults code-graph](0008-audit-chain-code-graph-integration.md) | Deprecated: code-graph Step 0.5 is no longer an active audit requirement. |

## Reading Order

For current work, read:

1. [`../BASELINE.md`](../BASELINE.md)
2. [`../PRD.md`](../PRD.md)
3. [`../SPEC.md`](../SPEC.md)
4. This transition index
5. Individual ADRs only when the rationale matters for the slice
