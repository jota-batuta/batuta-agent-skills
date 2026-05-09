---
name: multi-tenant-connector-pattern
description: Use when designing domain connectors for multi-tenant AI agents. Enforces one connector per ERP/domain, parameterized by tenant profile.
---

# Multi-Tenant Connector Pattern

## Overview

In a 6-layer agent, the connector layer (Capa 1) must be reusable across tenants. The same connector code serves multiple clients; only configuration, credentials, and mapping differ per tenant.

## When to Use

- Before writing any ERP, CRM, or external system integration.
- When the agent must support multiple tenants with the same domain (e.g., Siigo, SAP, Odoo).

## Process

1. Identify the domain (ERP, bank, provider).
2. Create a single connector module that accepts a tenant profile (config, credentials, mapping rules).
3. Never hardcode tenant-specific values inside the connector.
4. Store tenant profiles in config or secrets manager, never in code.

## Verification

- The connector can be instantiated with at least two different tenant profiles without code changes.
- All tenant-specific data lives outside the connector source.

## Red Flags

- Tenant name, bank code, or ERP instance ID inside the connector logic.
- Separate connector files per tenant.