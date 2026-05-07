---
name: code-graph
description: '[DEPRECATED v4.1] Maps code dependencies — use codebase-flow-mapper for architecture diagrams, grep+read for call-site queries'
deprecated: true
deprecated_in: v4.1
replaced_by: "codebase-flow-mapper (static diagrams), grep+read (live queries)"
---

# Code Graph — Deprecated (v4.1)

> **⚠️ DEPRECATED — v4.1**
>
> This skill is no longer active. Do not invoke it.
>
> **Replacements:**
> - For architecture diagrams → use `codebase-flow-mapper`
> - For call-site queries → use `grep` + `Read` directly
>
> This file is preserved for historical reference only. Full history in git log.

This skill was deprecated in v4.1. Investigation showed:

- Step 0.5 in `code-reviewer` and `security-auditor` was explicitly non-blocking; removing it produces no worse review output.
- Zero consumer projects adopted `rules/integrations/code-graph-usage.md`.
- The MCP engine (`codebase-memory-mcp`) was never installed in any active project.
- For repos under 10k LOC, `grep` + `read` is faster and uses fewer tokens.

## Replacements

| Use case | Replacement |
|---|---|
| Architecture diagram | `codebase-flow-mapper` skill — generates versioned Mermaid diagrams from source files |
| "What calls X" | `grep -r "X(" --include="*.py"` + Read call sites directly |
| "Find cycles" | `grep -r "^from X import\|^import X"` + manual graph |
| "Blast radius" | `grep -r "def modified_func"` + read immediate callers |

## History

- v2.8: introduced (dual-engine: graphify + codebase-memory-mcp)
- v3.0: integrated into audit chain Step 0.5 as non-blocking enrichment
- v4.0: graphify deprecated (ADR-0013); single-engine codebase-memory-mcp
- v4.1: skill deprecated; Step 0.5 removed from code-reviewer and security-auditor; codebase-flow-mapper covers 80% of use cases with zero MCP dependency
