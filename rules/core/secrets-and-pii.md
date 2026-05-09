---
title: Secrets and PII handling
applies-to: ["any-language", "regulated-data", "auth-systems"]
last-reviewed: 2026-05-09
enforcement: context-only
---

# Secrets and PII handling

1. Environment variables holding secrets MUST be validated at process startup. Missing or empty → exit with clear error. No silent fallback to `None`/`undefined`/empty.
2. Secrets passed via OS env vars, secret manager, or platform config injection. Never via: committed `.env` files, CLI arguments visible in `ps aux`, hardcoded defaults.
