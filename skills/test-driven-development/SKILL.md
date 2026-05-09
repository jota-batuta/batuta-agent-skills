---
name: test-driven-development
description: Drives development with tests. Use when implementing any logic, fixing any bug, or changing any behavior. Use when you need to prove that code works, when a bug report arrives, or when you're about to modify existing functionality.
---

# Test-Driven Development

## The Prove-It Pattern (Bug Fixes)

When a bug is reported, do NOT start by trying to fix it. Start by proving it exists:

1. **Write a reproduction test** that demonstrates the bug.
2. **Run it -- confirm it FAILS** (RED). This proves the bug exists.
3. **Implement the fix.**
4. **Run it -- confirm it PASSES** (GREEN). This proves the fix works.
5. **Run full test suite** -- no regressions.

The reproduction test is now a permanent regression guard.

## New Functions

For new functions, write the failing test before the implementation.
