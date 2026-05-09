---
title: Research-first citations
applies-to: ["python", "typescript", "any-language-with-imports"]
last-reviewed: 2026-05-09
enforcement: context-only
---

# Research-first citations

1. Add a citation comment at every external import site: `// Source: <url> (verified YYYY-MM-DD, <lib>@<version>)`. Python: `# Source:`. SQL: `-- Source:`.
2. If no reliable prior art exists, label the code as invented in the build-log and add tests that prove the claimed behavior.
