---
title: Tenant-ready design
applies-to: ["python", "typescript", "architecture", "tests"]
last-reviewed: 2026-05-09
enforcement: context-only
# §A.6 evidence: derived from the operator's global multi-tenant mandate and
# repeated financial reconciliation pipelines where bank/env/format variation
# had to move from code branches into profiles, adapters, and fixtures.
---

# Tenant-ready design

Multi-tenant is the starting design constraint, not a later refactor. A system
serving one client with three banks, three formats, or three rule sets is already
multi-context. Treat every varying bank, provider, environment, format, rule, or
period as a tenant/context boundary from the first slice.

## Inviolable rules

1. Model every business variation outside core logic: profiles, adapters,
   rulesets, schema maps, fixtures, or config.
2. Pass an explicit context object into core workflows. Do not read client,
   bank, provider, or environment identity from globals inside business logic.
3. Keep core logic deterministic and context-agnostic. It may orchestrate a
   profile or adapter; it must not branch on tenant names.
4. Put external formats behind adapters. CSV columns, Excel sheet names, account
   codes, provider enums, and API quirks belong at the boundary.
5. Test every varying behavior with at least two contexts before merge. One
   context verifies a happy path; two contexts verify the abstraction.
6. Make profiles IA-first: small, named, documented, machine-readable, and easy
   for agents to diff, copy, and extend.
7. Record context assumptions in fixtures or config comments, not in chat-only
   explanations.
8. When prior art exists, adapt its tenant/context boundary before inventing a
   new one.

## Allowed patterns

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class BankProfile:
    slug: str
    date_format: str
    amount_column: str
    account_code_map: dict[str, str]

def reconcile(rows: list[dict], profile: BankProfile) -> list[dict]:
    return [
        normalize_row(row, date_format=profile.date_format, amount_column=profile.amount_column)
        for row in rows
    ]
```

```typescript
type TenantContext = {
  tenantSlug: string;
  environment: "sandbox" | "production";
  provider: "bank-a" | "bank-b";
  rulesetVersion: string;
};

export function selectAdapter(context: TenantContext, registry: AdapterRegistry): BankAdapter {
  return registry.get(context.provider, context.rulesetVersion);
}
```

```python
import pytest

@pytest.mark.parametrize("profile_fixture", ["bank_a_profile", "bank_b_profile"])
def test_reconcile_supports_multiple_bank_contexts(profile_fixture, request):
    profile = request.getfixturevalue(profile_fixture)
    rows = load_fixture(profile.slug)
    assert reconcile(rows, profile)
```

## Anti-patterns

Violates rules 1 and 3:

```python
if bank_name == "bank_a":
    date_format = "%d/%m/%Y"
else:
    date_format = "%Y-%m-%d"
```

Violates rules 2 and 4:

```typescript
const provider = process.env.BANK_PROVIDER;
export function parseRow(row: Row) {
  return provider === "bank-a" ? parseBankA(row) : parseBankB(row);
}
```

Violates rule 5:

```python
def test_reconcile_bank_a_only():
    assert reconcile(load_fixture("bank_a"), BANK_A_PROFILE)
```

Violates rule 6:

```json
{ "x": "A", "y": "1", "z": true }
```

## Documented exceptions

1. Throwaway scripts may inline a single context only when the file is outside
   product code, named as disposable, and blocked from becoming a shared path.
2. Migration shims may branch on legacy tenant names only at the adapter boundary
   and only while a dated deprecation plan exists.
