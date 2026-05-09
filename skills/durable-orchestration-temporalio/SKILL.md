---
name: durable-orchestration-temporalio
description: Use when implementing Capa 4 durable orchestration with Temporal.io: workflows, dual-mode, HITL gates, immutable Event History, retries, crash recovery.
---

# Durable Orchestration with Temporal.io

## Overview

Capa 4: Use Temporal.io as the standard for reliable, long-running agent workflows that survive crashes, support human-in-the-loop, and provide immutable audit history.

## When to Use

- Any agent that must run unattended, retry automatically, or coordinate multiple steps over hours/days.

## Process

1. Model the agent as Temporal Workflow + Activities.
2. Implement dual-mode (prompt-driven vs autonomous heartbeat).
3. Add explicit HITL gates with escalation logic.
4. Ensure Event History is immutable and queryable for compliance (SIC).

## Verification

- Workflow can be restarted after crash with full history.
- Human approval steps are explicit and logged.