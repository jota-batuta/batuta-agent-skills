---
name: planning-and-task-breakdown
description: Breaks work into ordered tasks. Use when you have a spec or clear requirements and need to break work into implementable tasks. Use when a task feels too large to start, when you need to estimate scope, or when parallel work is possible.
---

# Planning and Task Breakdown

## Saving the Plan

Plan-mode in Claude Code writes plans to `~/.claude/plans/` -- a user-global ephemeral location that does not travel with the repo. This section covers copying the most recently modified plan to `docs/plans/active/<YYYY-MM-DD>-<slug>.md` so it is committed, versioned, and discoverable in the next session.

### Steps

1. **Locate source:** `ls -t ~/.claude/plans/*.md 2>/dev/null | head -1`. If empty, abort: *"No plan found in ~/.claude/plans/. Run plan mode first."*

2. **Verify skeleton:** `docs/plans/active/` must exist. If absent, abort: *"Project lacks doc skeleton. Run batuta-project-hygiene mode=project-retrofit first."* Do not create the directory inline.

3. **Compute target path:**
   - Date: `date +%Y-%m-%d`
   - Slug: if `$ARGUMENTS` is non-empty, use it (kebab-case, <=50 chars). Otherwise take source basename, strip `.md`, keep first 3-4 meaningful words (drop random suffixes).
   - Target: `docs/plans/active/<YYYY-MM-DD>-<slug>.md`

4. **Idempotency:** If target exists, abort. Do NOT overwrite -- overwriting silently destroys a plan the audit chain may have referenced.

5. **Copy and verify:** `cp "<source>" "<target>"`. Verify byte counts match (`wc -c` on both).

6. **Confirm:** Print the target path. Suggest the user-global copy can be deleted manually.

### Save-Plan Red Flags

- `~/.claude/plans/` contains multiple `.md` files from concurrent sessions -- verify the `head -1` pick matches the session just closed.
- Target path collides with an existing plan of different scope -- pick a distinct slug.
- `docs/plans/active/` has more than one file -- smell that a prior slice closed without archiving.

## Mapping Codebase Flow

Generate Mermaid diagrams representing a pipeline or tool's architecture at three levels of detail (system, module internals, data lineage) with automated analysis.

### When to Map

- Operator asks to "diagram the pipeline", "map the architecture", or "I need to understand how this connects"
- Project has >5 source modules and no `docs/pipeline-architecture.md`
- Before a large refactor to understand blast radius

### Steps

1. **Scan** -- Read manifest, find source modules, identify entry point, record language.

2. **Build module graph** -- For each source file: extract internal imports, public functions, cross-module calls, and I/O (files read/written, APIs consumed/served).

3. **Generate three Mermaid diagrams:**
   - **Diagram 1 -- System view (`flowchart TB`):** Subgraphs by pipeline phase. Nodes = modules. Edges = imports. Data sources as cylinders.
   - **Diagram 2 -- Module internals (`flowchart LR`):** One subgraph per module. Nodes = public functions. Edges = internal call graph. Entry points bolded.
   - **Diagram 3 -- Data lineage (`flowchart TB`):** Nodes = files/tables/APIs. Edges labeled by module.func. Flag ownership conflicts and duplicate sources of truth.

4. **Mermaid syntax rules (non-negotiable):**
   - Always `flowchart`, never `graph`.
   - Subgraph IDs: `subgraph ID["Label text"]` -- no bare quotes.
   - No `direction` declarations inside subgraphs.
   - No `@`, `x`, `->`, `(`, `)` in labels -- plain text only.
   - Connections within subgraph: inside the block. Between subgraphs: after all blocks.
   - Multiline labels: `<br/>`, not literal newlines.
   - Node IDs: alphanumeric and underscores only.

5. **Automated analysis** -- Scan for and list:

   | Finding | Detection |
   |---|---|
   | Orphaned functions | Public functions with zero callers |
   | Ownership conflicts | Files/tables written by >1 module |
   | Duplicate sources of truth | Same data read from >1 source |
   | Circular dependencies | Cycles in inter-module imports |
   | Oversized modules | >7 public functions (split candidates) |

6. **Output** -- Write `docs/pipeline-architecture.md`: header (project, date, commit), three fenced Mermaid blocks, analysis table, recommendations. If file exists, overwrite entirely (regenerated from code, not maintained by hand).

### Flow-Mapper Red Flags

- Generating diagrams without reading source files (guessing from names)
- Using `graph` instead of `flowchart`
- Putting `direction` inside subgraphs (breaks rendering)
- Skipping analysis step and delivering only diagrams
- >50 nodes in a single Mermaid block (split by layer)
- Omitting data lineage because "the project is simple"

### Flow-Mapper Verification

1. Paste each Mermaid block into mermaid.live -- must render without errors.
2. Every source module appears in Diagram 1.
3. Every public function appears in Diagram 2.
4. Analysis list is non-empty OR explicitly states "no findings" with scope documented.
5. `ls docs/pipeline-architecture.md` returns the file.
