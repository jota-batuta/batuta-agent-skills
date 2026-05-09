---
id: IC-011
slug: fix-bashrc-syntax-error
date: 2026-05-05
status: confirmed
---

# IC-011 — Fix .bashrc syntax error

## Intent

Delete orphaned fragment (lines 150-155) in `~/.bashrc` that causes
`syntax error near unexpected token 'fi'` on shell startup.

## Routing

main-direct — single mechanical edit, no logic.
