# Skill Map

This map is the operational consolidation layer for the Claude Code plugin. It
keeps existing skill names stable while declaring which skills are primary,
wrappers, specialized workflows, or deprecated historical stubs.

## Primary Hot Path

| Stage | Primary skill | Notes |
|---|---|---|
| Route | `using-agent-skills` | Short router; long examples moved to `references/using-agent-skills-longform.md`. |
| Confirm | `intent-capture` | Mandatory for concrete work. Owns intent and routing markers. |
| Context | `context-engineering` | Short context packer; examples moved to `references/context-engineering-playbook.md`. |
| Prior art | `research-first-dev` | Active prior-art-first workflow; supersedes `source-driven-development`. |
| Build | `incremental-implementation` | Slice-by-slice implementation. |
| Verify | `test-driven-development` | Primary verification workflow. |
| Review | `code-review-and-quality` | Main audit gate before close. |
| Ship | `git-workflow-and-versioning`, `slice-close` | Git and slice closure. |

## Compatibility Wrappers

| Skill | Status | Active replacement |
|---|---|---|
| `source-driven-development` | Wrapper | `research-first-dev` |
| `slice-open` | Lifecycle wrapper | `slice-close` plus active plan conventions |
| `pr-prep` | Lifecycle wrapper | `slice-close` / PR guard workflow |
| `kb-end-session` | Lifecycle wrapper | KB lifecycle skills plus session journal rules |

## Specialized Active Skills

| Area | Skills |
|---|---|
| Product/API/UI | `api-and-interface-design`, `frontend-ui-engineering` |
| Quality axes | `debugging-and-error-recovery`, `security-and-hardening`, `performance-optimization`, `code-simplification` |
| Delivery | `ci-cd-and-automation`, `shipping-and-launch`, `documentation-and-adrs`, `deprecation-and-migration` |
| KB | `batuta-kb-vault`, `kb-curate`, `kb-backfill`, `batuta-status`, `vault-health` |
| Authoring gates | `batuta-skill-authoring`, `batuta-agent-authoring`, `batuta-rule-authoring` |
| Browser/runtime | `browser-testing-with-devtools` |
| Architecture diagrams | `codebase-flow-mapper` |

## Deprecated Historical Stubs

| Skill | Replacement |
|---|---|
| `code-graph` | `codebase-flow-mapper` for diagrams; direct search/read for call-site queries |

## Vendored Skills

Vendored skills under `skills/_vendored/` are dependencies, not Batuta workflow
ownership points. Do not edit vendored content in this repo; wrap it from a
first-party skill when Batuta policy is needed.

## 6-Layer Agent Harness (new in this pass)

When the operator describes an AI Agent project, `batuta-project-hygiene` scaffolds the 6-layer harness first:

1. Multi-tenant Connector Pattern
2. Rules-as-Code Authoring
3. Memory Architecture Design
4. Durable Orchestration (Temporal.io)
5. Observability Contract
6. Agent Heartbeat & Execution Autonomy

All new agent work must follow the harness-first order enforced by `research-first-dev`.

## Consolidation Rules

- Keep public skill names for at least one release after changing behavior.
- Put long examples in `references/`; keep hot path skills under 150 lines.
- Prefer one primary owner per decision. Wrappers must route quickly instead of
  duplicating process.
- Authoring gate skills remain separate because hooks depend on their names.
- Deprecated skills must name the replacement and preserve ADR traceability.
