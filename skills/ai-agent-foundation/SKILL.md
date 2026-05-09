---
name: ai-agent-foundation
description: Design the foundational data layer for a multi-tenant AI agent system -- domain connectors, versioned business rules, and tenant-scoped memory. Use when starting a new AI agent project or adding a new domain to an existing one.
---

# AI Agent Foundation

## TenantProfile Contract

Every connector must accept a `TenantProfile` parameter -- never a tenant name string, never an environment variable name, never a hardcoded identifier.

```typescript
interface TenantProfile {
  tenant_id: string;                    // Unique identifier, never hardcoded
  credentials: {
    api_key: string;
    api_secret: string;
    base_url: string;
  };
  mapping_rules: {
    account_code_map: Record<string, string>;
    tax_category_map: Record<string, string>;
  };
  config: {
    retry_attempts: number;
    timeout_ms: number;
    locale: string;
  };
}
```

Four required field groups: `tenant_id`, `credentials`, `mapping_rules`, `config`. The connector uses these fields for every operation -- auth, mapping, and behavior.

## Connector Rule

The connector constructor or factory function accepts a `TenantProfile` parameter. Every method uses fields from the profile. The same connector code serves multiple clients; only configuration differs per tenant.

## Memory Query Rule

Every memory query must include `tenant_id` as a primary filter. A query without tenant scoping is a data leak. This applies to relational queries, vector search, and event log lookups equally.

## Rules-as-Code

Rule modules are pure functions with typed inputs and an explicit `RULE_VERSION` field.

- Export a semver version (`RULE_VERSION = '1.2.0'`).
- Accept typed inputs including `tenant_id`, domain-specific fields, and temporal context (fiscal year, period).
- Return a result that includes `rule_version` and `applied_regulation` for audit trails.
- No side effects, no I/O -- pure computation only.
- Bump version on every change. Include version in output so audit logs record which version produced each decision.

## Cross-Tenant Isolation Test

A test must exist that proves queries for one tenant never return another tenant's data. This test must cover relational queries, vector search, and event logs. It must exist before any memory layer goes to production.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This connector is only for one tenant right now" | Hardcoding the first tenant forces a rewrite for the second. The parameterized design costs the same to write. |
| "The tenant config can go in a comment for now" | Comments become code. Tenant config in a comment becomes tenant config in the connector at code review. |
| "We don't have a secrets manager yet" | Write to `.env.local` + TenantProfile shape. Storage is swappable; the connector contract is not. |
| "The logic is too simple to extract" | Simple logic in a prompt becomes invisible; in a versioned module it is auditable and testable. |
| "The rule changes every month, why version it?" | Frequent change is exactly why versioning matters -- each change is tracked, rollback is possible. |
| "I'll add tests later" | Rules without tests are assertions without evidence. |
| "Memory isolation is a later concern" | Tenant leakage discovered post-launch requires a data audit and potential breach notification. Isolation must be in the schema from day one. |
| "Vector search doesn't support tenant filtering" | pgvector, Qdrant, and Pinecone all have tenant isolation mechanisms. |
| "Replay is too expensive to design upfront" | Replay is the only way to debug agent decisions post-incident. Without it, any production anomaly is opaque. |

## Red Flags

- Tenant ID hardcoded as string literal inside connector logic
- Separate connector files per tenant
- Credentials in constructor instead of profile parameter
- No unit test with more than one profile
- Business logic inside an LLM prompt string
- `if tenant_id == "literal"` patterns in orchestration code
- No unit tests for rule module; no version identifier
- Queries without `tenant_id` in WHERE/filter clause
- Memory entries without a creation timestamp
- No test that proves cross-tenant reads return empty
- Shared vector DB namespace across tenants

## Verification

- [ ] TenantProfile interface exists with tenant_id, credentials, mapping_rules, config
- [ ] Connector accepts TenantProfile, not a hardcoded tenant identifier
- [ ] >= 2 unit tests instantiate connector with different profiles
- [ ] Rule module exists at `rules/<domain>/<name>` with typed inputs and version field
- [ ] >= 2 unit tests cover tenant variations and at least one boundary condition
- [ ] Every memory query includes tenant_id as a primary filter
- [ ] Cross-tenant isolation test passes (queries return empty for wrong tenant)
- [ ] Replay mechanism documented and tested
