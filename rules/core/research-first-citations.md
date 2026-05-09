---
title: Research-first citations
applies-to: ["python", "typescript", "any-language-with-imports"]
last-reviewed: 2026-05-09
enforcement: context-only
# §A.6: derived from the operator's global research-first mandate, now clarified
# as prior-art-first across all Batuta sessions.
---

# Research-first citations

Research-first means prior-art-first: look for a proven solution, copy or adapt
it when it fits, and invent only when no reliable prior art exists. Citations
make that evidence durable at the import, call, adapter, or decision site.

## Inviolable rules

1. Before writing code that uses any external library, API, service, CLI, or
   copied reusable pattern, produce an evidence pack: source, version/context,
   selected approach, rejected alternatives, license risk, and verification.
2. Search in this order: curated Batuta KB, existing project code, mature
   open-source implementations, official documentation, changelog/release notes,
   then source repository. Use Context7 for library/API docs when available.
3. Add a `// Source:` citation comment at the import, call, adapter, or copied
   pattern site with format `// Source: <url-or-path> (verified YYYY-MM-DD,
   <lib-or-project>@<version-or-commit>)`. In Python use `# Source:`; in SQL use
   `-- Source:`.
4. When adapting open-source code, record repository, commit/tag, license, files
   adapted, and any incompatible license risk before staging the change.
5. Re-verify and update the citation any time the dependency version, API
   version, provider contract, or copied upstream commit changes.
6. If no reliable prior art exists, label the code as invented in the build-log
   or decision record and add tests that prove the claimed behavior.

## Allowed patterns

```python
# Source: ~/batuta-kb/gotchas/provider-pagination.md (verified 2026-05-09)
# Cross-checked: https://docs.provider.example/pagination (verified 2026-05-09, provider-api@2026-04)
from provider import Client
```

```typescript
// Source: https://github.com/example/project/blob/v1.4.2/src/retry.ts (verified 2026-05-09, example/project@v1.4.2, MIT)
import { createRetryPolicy } from "./retryPolicy";
```

```python
# Source: https://docs.pydantic.dev/2.7/ (verified 2026-05-09, pydantic@2.7.1)
from pydantic import BaseModel, field_validator
```

Evidence pack in a build-log or ADR:

```markdown
Prior art: example/project retry policy at v1.4.2, MIT.
Adapted: backoff schedule only; dropped logging wrapper.
Rejected: blog tutorial because it lacked version and license.
Verification: unit tests cover timeout and retry exhaustion.
```

## Anti-patterns

```python
# Bad - violates rules 1 and 3: no prior-art lookup, no citation.
import stripe
```

```typescript
// Bad - violates rule 2: unofficial source used as primary proof.
// Source: https://stackoverflow.com/questions/12345678 (verified 2026-05-09, axios@1.6.0)
import axios from "axios";
```

```python
# Bad - violates rule 4: copied implementation lacks repository, commit, license.
def retry(fn):
    ...
```

```markdown
Bad - violates rule 6: "No docs found, implemented from memory" with no tests
and no invented-code marker in the build-log.
```

## Documented exceptions

- Standard library imports: no citation required.
- Internal packages in the same monorepo/workspace: no citation required unless
  the import crosses a published API contract.
- Test runner imports are exempt for the runner itself; plugins, matchers, and
  external fixtures still require citations.
