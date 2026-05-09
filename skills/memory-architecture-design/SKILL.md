---
name: memory-architecture-design
description: Use when designing the memory layer (Capa 3) for agents: what to persist, how to version, how to retrieve per tenant.
---

# Memory Architecture Design

## Overview

Capa 3: Agents need durable, queryable memory that respects tenant boundaries and supports replay/debug.

## When to Use

- Before any stateful agent that must remember past interactions, decisions, or outcomes across sessions.

## Process

1. Define what must be remembered (decisions, events, state snapshots).
2. Choose storage (vector DB, event log, relational) per access pattern.
3. Ensure tenant isolation in every query.
4. Design for replay and explainability.

## Verification

- Memory entries are tenant-scoped.
- Can replay a tenant's history without leaking other tenants' data.