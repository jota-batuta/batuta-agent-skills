---
id: IC-014
slug: codebase-flow-mapper-skill
date: 2026-05-06
status: confirmed
---

# IC-014 — Create codebase-flow-mapper skill

## Intent

New skill that generates Mermaid diagrams representing pipeline/tool architecture
at three levels (system, module internals, data lineage) with automated analysis
of redundancies, circular dependencies, orphaned functions, and duplicate sources
of truth. Output: `docs/pipeline-architecture.md`.

## Discovery proof

Three searches against skills.sh (91k+ catalog):

1. `mermaid architecture diagram codebase` — top: softaworks/mermaid-diagrams (4K installs, generic, no data lineage). FAIL install bar.
2. `codebase flow mapper pipeline visualization` — top: shoootyou/gsd-map-codebase (43 installs). FAIL.
3. `code dependency graph data lineage` — top: astronomer/tracing-upstream-lineage (650 installs, Airflow-specific). FAIL.

No candidate passes the ≥10K install bar or covers the 3-level analysis scope.

## Routing

main-direct — single documentation file (SKILL.md), no executable code.
