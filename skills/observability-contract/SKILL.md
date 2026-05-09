---
name: observability-contract
description: Use when designing Capa 5 observability for agents: Langfuse integration, 14 audit fields, confidence scoring, drift detection, explainability.
---

# Observability Contract

## Overview

Capa 5: Every agent must emit structured telemetry that allows the customer to understand exactly why each decision was made.

## When to Use

- Before any production agent that interacts with customers or automated processes.

## Process

1. Integrate Langfuse (or equivalent) with the 14 required audit fields.
2. Add confidence scoring on every LLM call.
3. Implement drift detection on key metrics.
4. Expose decision trace to the operator.

## Verification

- Every agent action produces a traceable event with all 14 fields.
- Customer can query "why did the agent do X" in < 30 seconds.