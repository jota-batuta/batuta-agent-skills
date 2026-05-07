---
name: codebase-flow-mapper
description: Use when the operator asks to diagram a pipeline or map architecture. Auto-triggers on projects with >5 modules and no docs/pipeline-architecture.md.
---

# Codebase Flow Mapper

## Overview

Generate Mermaid diagrams that represent a pipeline or tool's architecture at three levels of detail — system, module internals, and data lineage — with automated analysis of redundancies, circular dependencies, orphaned functions, and duplicate sources of truth.

## When to Use

- Operator asks to "diagram the pipeline", "map the architecture", or "I need to understand how this connects"
- Project has >5 source modules and no `docs/pipeline-architecture.md` or equivalent
- Before a large refactor to understand blast radius
- During onboarding to a new codebase

Do NOT use when:

- The codebase has <3 modules (a single-file walkthrough is faster)
- The operator only needs a live call graph query (use `code-graph` instead — MCP-backed)
- The diagram already exists and the operator wants to update one section (edit directly)

## Process

### Step 1 — Scan

1. Read the manifest (`pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`).
2. `find` source modules in `src/`, `lib/`, `app/`, or the project-specific source root.
3. Identify the entry point (the script or module that orchestrates the pipeline).
4. Record the language — this determines import/function parsing strategy.

### Step 2 — Build the module graph

For each source file (`.py`, `.ts`, `.rs`, `.go`) in the source root:

1. **Imports** — extract internal imports only (skip stdlib and external packages).
2. **Public functions** — extract functions not prefixed with `_` (Python), not marked `private` (Rust), or exported (TypeScript/Go).
3. **Cross-module calls** — for each public function, record which functions from other modules it calls.
4. **I/O** — record files read (`open`/`read`/`load` calls) and files written (`open`/`write`/`save`/`dump` calls), including API endpoints consumed or served.

### Step 3 — Generate three Mermaid diagrams

**Diagram 1 — System view (`flowchart TB`)**

Subgraphs by pipeline phase or layer. Nodes = modules. Edges = import dependencies. Data sources and outputs as cylinder-shaped nodes (`[(label)]`).

**Diagram 2 — Module internals (`flowchart LR`)**

One subgraph per module. Nodes = public functions. Edges = internal call graph (function A calls function B). Mark functions called from other modules with bold borders (`:::entrypoint`).

**Diagram 3 — Data lineage (`flowchart TB`)**

Nodes = files, tables, or APIs. Edges labeled `"read by module.func"` or `"written by module.func"`. Flag conflicts: two functions writing the same target (ownership ambiguity) or one datum read from two distinct sources (duplicate source of truth).

**Mermaid syntax rules (non-negotiable):**

- Always `flowchart`, never `graph`.
- Subgraph IDs: `subgraph ID["Label text"]` — no bare quotes.
- No `direction` declarations inside subgraphs.
- No `@`, `×`, `→`, `(`, `)` in labels — use plain text only.
- Connections within a subgraph: declare inside the subgraph block.
- Connections between subgraphs: declare after all subgraph blocks.
- Multiline labels: use `<br/>`, not literal newlines.
- Node IDs: alphanumeric and underscores only.

### Step 4 — Automated analysis

After generating the diagrams, scan for and list:

| Finding | Detection |
|---|---|
| Orphaned functions | Public functions with zero callers across the entire graph |
| Ownership conflicts | Files or tables written by >1 module |
| Duplicate sources of truth | Same logical data read from >1 distinct source |
| Circular dependencies | Cycles in the inter-module import graph |
| Oversized modules | Modules with >7 public functions (split candidates) |

### Step 5 — Output

Write `docs/pipeline-architecture.md` with this structure:

1. **Header** — project name, date generated, commit hash.
2. **Diagram 1** — System view (fenced Mermaid block).
3. **Diagram 2** — Module internals (fenced Mermaid block).
4. **Diagram 3** — Data lineage (fenced Mermaid block).
5. **Analysis** — table of findings from Step 4, grouped by severity.
6. **Recommendations** — concrete next actions for each finding.

If the file already exists, overwrite it entirely. The diagram is regenerated from code, not maintained by hand.

## Anti-Rationalizations

| Excuse | Reality |
|---|---|
| "A module-only diagram is enough" | Without function-level detail you cannot detect redundancy or orphaned code |
| "Data lineage is overkill for this project" | Ownership conflicts are invisible without it — you discover them in production, not in review |
| "I'll describe the architecture in prose" | Prose goes stale on the first refactor. Mermaid renders from code and is re-runnable |
| "The code-graph skill already covers this" | code-graph does live MCP queries against a persisted graph. This skill produces a static, version-controlled visual artifact |
| "The codebase is too big for three diagrams" | Split Diagram 2 by layer. System and Data Lineage still fit — they operate at module granularity, not function |

## Red Flags

- Generating a diagram without reading actual source files (guessing from names)
- Producing Mermaid that uses `graph` instead of `flowchart`
- Putting `direction` declarations inside subgraphs (breaks rendering)
- Using Unicode arrows or special characters in node labels
- Skipping the analysis step and delivering only diagrams
- Generating a diagram with >50 nodes in a single block (split by layer or phase)
- Omitting data lineage because "the project is simple"

## Verification

1. **Syntax**: paste each fenced Mermaid block into mermaid.live — must render without errors.
2. **Completeness**: every source module in the scanned directory appears as a node in Diagram 1.
3. **Cross-reference**: every public function appears in Diagram 2; every inter-module call from Step 2 appears as an edge.
4. **Analysis**: the findings list is non-empty OR explicitly states "no findings" with the scan scope documented.
5. **File exists**: `ls docs/pipeline-architecture.md` returns the generated file.
