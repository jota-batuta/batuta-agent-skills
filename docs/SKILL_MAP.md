# Skill Map

This map is the operational consolidation layer for the Claude Code plugin.
It lists the 24 production skills organized by functional category.

## Hot Path (9)

The default build chain — every concrete task walks this sequence.

| Skill | Role |
|---|---|
| `intent-capture` | Tier assignment + grill-if-standard before implementation |
| `source-driven-development` | Source priority hierarchy for AI-first development |
| `research-first-dev` | 6-layer harness mandate + citation format |
| `incremental-implementation` | "NOTICED BUT NOT TOUCHING" scope discipline |
| `test-driven-development` | Prove-It pattern for bugs |
| `code-review-and-quality` | Quick/Thorough mode detection + severity prefixes |
| `slice-close` | Audit chain + PR + session close |
| `idea-refine` | Variation lenses + "Not Doing" list |
| `planning-and-task-breakdown` | Codebase flow mapper + plan persistence |

## Authoring Gates (3)

Skills that guard creation of new plugin artifacts. Hooks depend on these names.

| Skill | Scope |
|---|---|
| `batuta-skill-authoring` | Discover-first gate (91k+ catalog) |
| `batuta-agent-authoring` | Distinctness + tool minimality gate |
| `batuta-rule-authoring` | Two-project evidence gate |

## AI Agent Harness (2)

Two consolidated skills covering the 6-layer agent architecture.

| Skill | Role |
|---|---|
| `ai-agent-foundation` | TenantProfile + rules-as-code + memory isolation constraints |
| `ai-agent-runtime` | 14 audit fields + Temporal determinism + idempotency |

## KB Pipeline (4)

| Skill | Role |
|---|---|
| `batuta-kb-vault` | Obsidian vault 4-level architecture + health check |
| `kb-backfill` | Legacy repo extraction pipeline |
| `kb-curate` | L1->L2/L3 promotion with hybrid control |
| `kb-end-session` | Session journal close + curation trigger |

## Delivery (2)

| Skill | Role |
|---|---|
| `documentation-and-adrs` | Per-slice living docs mandate |
| `deprecation-and-migration` | Churn Rule + zombie code + 5 questions |

## Design (1)

| Skill | Role |
|---|---|
| `interface-and-ui-design` | Avoid AI Aesthetic + One-Version Rule + WCAG 2.1 AA |

## Plugin Maintenance (2)

| Skill | Role |
|---|---|
| `batuta-project-hygiene` | Feature-init + doc skeleton + KB hooks |
| `batuta-status` | Cross-project vault/git status + hook diagnosis |

## Specialized (1)

| Skill | Role |
|---|---|
| `browser-testing-with-devtools` | DevTools MCP security boundaries + tool catalog |

---

## Deleted Skills (v5.x adjustment)

| Deleted skill | Reason |
|---|---|
| `using-agent-skills` | Circular routing table |
| `context-engineering` | Native Claude behavior |
| `git-workflow-and-versioning` | Native Claude behavior |
| `quality-axes` | Training data reformatted |
| `ci-cd-and-automation` | Generic DevOps |
| `shipping-and-launch` | Generic DevOps |
| `spec-driven-development` | Claude Code built-in plan mode |

## Merged Skills (v5.x consolidation)

Skills consolidated during the v5.x refactor:

| Absorbed skill(s) | Merged into |
|---|---|
| `rules-import` | `batuta-rule-authoring` |
| `save-plan`, `codebase-flow-mapper` | `planning-and-task-breakdown` |
| `vault-health` | `batuta-kb-vault` |
| `living-docs-maintenance` | `documentation-and-adrs` |
| `hooks-diagnose` | `batuta-status` |
| `api-and-interface-design`, `frontend-ui-engineering` | `interface-and-ui-design` |
| `multi-tenant-connector-pattern`, `rules-as-code-authoring`, `memory-architecture-design` | `ai-agent-foundation` |
| `durable-orchestration-temporalio`, `observability-contract`, `agent-heartbeat-autonomy` | `ai-agent-runtime` |
| `debugging-and-error-recovery`, `security-and-hardening`, `performance-optimization`, `code-simplification` | `quality-axes` (then deleted) |
| `slice-open`, `pr-prep` | Removed (redundant with `slice-close`) |
