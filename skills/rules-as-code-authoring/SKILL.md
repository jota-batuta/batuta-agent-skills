---
name: rules-as-code-authoring
description: Use when encoding business rules as versioned, testable code instead of prompts or hardcoded logic.
---

# Rules-as-Code Authoring

## Overview

Capa 2: Business rules must be explicit, versioned, and testable code, not buried in prompts or LLM behavior.

## When to Use

- Before adding any conditional business logic that varies by tenant, period, or regulation.

## Process

1. Extract the rule into a dedicated module or config file.
2. Make it data-driven or rule-engine driven when possible.
3. Version the rule file with the codebase.
4. Write unit tests for the rule in isolation.

## Verification

- Rule can be changed without touching agent orchestration code.
- Tests cover at least two tenant variations.