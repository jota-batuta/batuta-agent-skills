---
title: Code Graph Usage (Deprecated)
applies-to: [markdown, shell]
last-reviewed: 2026-05-09
deprecated: true
enforcement: context-only
---

# Code Graph Usage (Deprecated)

This rule is preserved as historical reference for the v2.8-v4.1 code-graph
era. It is not an active operating rule for new work. Use
`skills/codebase-flow-mapper/SKILL.md` for static architecture diagrams and
direct search/read workflows for live call-site questions.

## Inviolable rules

1. Treat `skills/code-graph/SKILL.md` as deprecated; do not route new slices to
   code-graph as the default architecture discovery path.
2. Never run `graphify claude install`; it is a forbidden integration command in
   this plugin.
3. Keep code-graph helper scripts away from `.claude/settings*.json`; that path
   is a kill-switch surface, not a generated output target.
4. Keep historical ADR references intact when editing this file, because this
   rule exists for traceability across deprecated graph integrations.
5. Use `codebase-flow-mapper` when the operator asks for pipeline or architecture
   diagrams.
6. Use direct repository search plus focused file reads when the operator asks
   for call sites, imports, or blast radius in repositories under 10k LOC.

## Allowed patterns

Use the replacement skill for architecture diagrams:

```bash
claude "Use codebase-flow-mapper to map the request pipeline and write docs/pipeline-architecture.md"
```

Use direct search for live call-site questions:

```bash
rg "target_function\\(" src tests
```

Preserve the deprecated rule while making the replacement explicit:

```markdown
Deprecated: code-graph
Replacement: codebase-flow-mapper for diagrams; direct search/read for live queries
ADR trace: docs/adr/0007-code-graph-dual-engine.md
```

## Anti-patterns

Anti-pattern for Rule 1:

```markdown
Use code-graph before every review.
```

Anti-pattern for Rule 2:

```bash
graphify claude install
```

Anti-pattern for Rule 3:

```bash
printf '%s\n' '{"hooks":{}}' > .claude/settings.json
```

Anti-pattern for Rule 5:

```markdown
Ask code-graph to generate the pipeline architecture diagram.
```

## Documented exceptions

1. Historical documentation and validators may mention `code-graph`,
   `graphify`, and `codebase-memory-mcp` when the text clearly labels the system
   as deprecated or preserved for ADR traceability.
2. Legacy helper scripts may remain in `tools/` while validators assert that
   they do not mutate Claude Code settings or invoke forbidden install commands.
