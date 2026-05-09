---
name: deprecation-and-migration
description: Manages deprecation and migration. Use when removing old systems, APIs, or features. Use when migrating users from one implementation to another. Use when deciding whether to maintain or sunset existing code.
---

# Deprecation and Migration

## The Churn Rule

If you own the infrastructure, you are responsible for migrating your users. You cannot just break them and say "update your code." Provide backward-compatible updates, migration tooling, or do the migration yourself.

## Zombie Code

Code nobody owns but everybody depends on. Signs:

- No recent commits (6+ months) but active consumers exist
- No assigned maintainer or CODEOWNERS entry
- Failing tests nobody fixes
- Dependencies with known vulnerabilities nobody updates

Response: either assign an owner and invest, or deprecate with a concrete migration plan. Zombie code cannot stay in limbo.

## 5 Questions Before Deprecating

1. **Is anyone using this?** Verify with metrics, logs, dependency analysis.
2. **How many consumers?** Quantify the migration scope.
3. **Does a replacement exist?** Never deprecate without an alternative.
4. **What's the migration cost?** If trivially automated, do it. If manual and high-effort, weigh against maintenance cost.
5. **What's the ongoing maintenance cost of NOT deprecating?** Security risk, engineer time, opportunity cost.

## Decision Framework

| Type | When | Mechanism |
|---|---|---|
| **Advisory** | Old system is stable, migration is optional | Warnings, documentation, nudges. Users migrate on their own timeline. |
| **Compulsory** | Security issues, blocks progress, or maintenance cost is unsustainable | Hard deadline. Removal by date X. Must provide migration tooling, documentation, and support. |

Default to advisory. Use compulsory only when maintenance cost or risk justifies forcing migration.
