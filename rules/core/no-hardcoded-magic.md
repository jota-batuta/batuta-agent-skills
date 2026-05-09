---
title: No hardcoded magic values
applies-to: ["python", "typescript", "bash", "markdown"]
last-reviewed: 2026-05-09
enforcement: context-only
---

# No hardcoded magic values

## Inviolable rules

1. Every value that varies by client, tenant, environment, or external schema MUST be in a config module or env var. Inline literals for such values are prohibited in business logic.
2. Tests MUST exercise at least 2 distinct configurations before merge.
3. **This rule applies to the plugin itself, not only to client code.** Shell hooks, agent definitions, skill files, and tooling scripts are subject to the same constraint. Marker names, timeout thresholds, path conventions, repo identity strings, model tier names, exempt path lists, and bypass env var names MUST be read from `hooks/plugin-config.json` — never written as inline literals in hook logic.
4. When writing or editing a `.sh` file under `hooks/`, the agent MUST source `hooks/lib.sh` and use its accessor functions (`cfg`, `marker_name`, `timeout_val`, `config_path`, `is_bypassed`, `repo_pattern`, `is_exempt_path`, `is_kill_switch_path`, `find_fresh_marker`) instead of writing literal values. Introducing a new configurable value means adding it to `plugin-config.json` first, then consuming it via `lib.sh`.
