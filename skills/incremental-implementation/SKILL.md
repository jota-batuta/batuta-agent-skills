---
name: incremental-implementation
description: Delivers changes incrementally. Use when implementing any feature or change that touches more than one file. Use when you're about to write a large amount of code at once, or when a task feels too big to land in one step.
---

# Incremental Implementation

Implement one slice at a time: code -> test -> verify -> commit -> next.

## NOTICED BUT NOT TOUCHING

When you notice something that needs fixing during implementation but is outside current scope, log it and continue. Do not fix it.

```
NOTICED BUT NOT TOUCHING:
- src/utils/format.ts has an unused import (unrelated to this task)
- The auth middleware could use better error messages (separate task)
```

Offer to create follow-up tasks for the logged items after the current slice is done.
