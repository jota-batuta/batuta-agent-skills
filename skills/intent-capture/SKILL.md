---
name: intent-capture
description: Use when the operator describes any concrete work to execute — edits, writes, commands, or changes to files, repos, or configs.
attribution: Grilling pattern derived from mattpocock/skills/grill-with-docs (https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)
---

# intent-capture

## Overview

**The agent NEVER executes work before capturing a confirmed intent.** Operators release ideas progressively and ambiguously. Acting on the first bullet produces rework. This skill enforces: grill → capture → confirm → route → execute, producing a JSON object conformant to `references/intent-schema.json` as the execution contract.

## When to Use

**Trigger on any operator message that requests concrete action**: verb in imperative, request to change files/repos/configs, feature description, bug report, or refactor ask.

**Do NOT trigger on**:
- Read-only questions ("what does X do?", "explain Y", "show me Z")
- Simple confirmations to an already-emitted intent ("yes", "go ahead", "ok")
- Mid-stream corrections to an intent in progress (merge into existing batch)

## Process

### Step 1: Detect

Identify whether the operator message is an action request or read-only. If read-only → exit, answer directly. If action → proceed to Step 2.

**Per-turn invariant (v4.3):** every operator turn arrives with a clean slate — the `clear-intent-marker.sh` UserPromptSubmit hook invalidated any prior marker AND emitted a system-reminder via `hookSpecificOutput.additionalContext` that authoritatively triggers this skill. Treat that injected reminder as the canonical signal, not your own pattern-matching of operator words. The single exception is short confirmations of an intent already in progress this turn ("sí", "dale", "procedé") — those do not start a new grill, they continue Step 5.

### Step 2: Grill

Ask **one concrete question per turn** until the ask is unambiguous. Stop asking when ALL THREE are clear for each ask: `text` (what exactly), `scope` (where it applies and where it does not), `acceptance` (how to verify it is done).

**Before asking the operator, check the codebase**: if the vault, ADRs, code-graph, or source files can answer the question, read them and cite the evidence instead of asking.

Taxonomy of questions (`references/grilling-taxonomy.md`):
- **Scope**: "Does this apply to file X only or also Y?"
- **Ambiguity**: "You said 'simplify' — reduce lines, improve readability, or remove features?"
- **Constraint**: "Any deadline? Runs in CI or local only? Touches production data?"
- **Rejected alternative**: "Did you consider X? Ruled out for a specific reason?"
- **Acceptance**: "How do we know it is done — a passing test, a specific output, a manual demo?"

Continue grilling until the stopping criterion is met. No hard cap on questions, but cite code evidence to reduce round-trips.

### Step 3: Capture

Build the JSON object conformant to `references/intent-schema.json`:
- `asks[]`: one item per distinct ask, each with `id`, `original_text`, `refined_text`, `scope`, `acceptance`, `priority`, `category`, `captured_at`, `clarifications[]` (the Q&A log).
- `metadata`: session_id, operator_id, created_at, agent_version.
- `status`: set to `"ready_for_confirmation"`.

### Step 4: Present

Display the JSON in a fenced markdown block. Add one closing line: "Is this everything, or do you have more asks?"

If the operator adds new asks → loop back to Step 2 for each new ask with `asks[]` extended. Do not re-grill already-confirmed asks.

### Step 5: Confirm

Wait for explicit confirmation ("yes, go ahead", "that's it", "proceed", or equivalent). On confirm:
- Set `status: "confirmed"`, record `confirmed_at` and `confirmed_via`.
- **Dual-write (v4.3)** — write BOTH artifacts:
  1. **Marker (audit token)**: `<project-root>/.claude/.intent-confirmed-<ISO-timestamp>` (UTC, RFC 3339, e.g. `.intent-confirmed-2026-05-04T18:42:00Z`). Empty file. Gitignored. Valid until next UserPromptSubmit invalidates it. Consumed by `pre-edit-intent-gate.sh`.
  2. **Persisted record (versioned artifact)**: `<project-root>/docs/intents/<YYYY-MM-DD>-<id>-<slug>.md` — markdown with YAML frontmatter (status, captured_at, confirmed_at, operator_id, agent_version, category, related_pr, related_branch) and a narrative body (Original ask, Refined intent, Scope in/out, Acceptance, Routing declaration, Outcome, Original JSON in fenced block at the end). Committed to git. See `docs/intents/README.md` for format.
- Marker-only is insufficient — confirmed intents are first-class development artifacts equivalent to ADRs (Rule 8).
- This JSON is the execution contract passed to the routed subagent.

### Step 6: Route and Execute

**v4.4 routing declaration + marker** — before any tool call within the confirmed intent's execution, the agent MUST:

1. Declare the routing decision to the operator in plain language. Format: a brief table or paragraph stating per file or scope, "Voy a usar [subagent X / main-direct] porque [reason]". The operator may approve as-is or override.
2. Wait for explicit operator approval ("dale", "procedé", "approved", or equivalent). This approval is SEPARATE from the intent-confirmation in Step 5 — even though both can come in the same operator message.
3. Write the routing marker: `<project-root>/.claude/.routing-confirmed-<ISO-timestamp>` (UTC, RFC 3339). Without this marker, the `pre-task-routing-gate.sh` hook blocks any `Task` tool call (subagent dispatch). The marker is invalidated by `clear-intent-marker.sh` at every UserPromptSubmit (turn boundary), parallel to the intent marker.
4. THEN execute — delegate to subagent via `Task`, or proceed main-direct.

Routing decisions are NOT at agent discretion. The hook + marker pair (parallel to the v4.3 intent gate) gives runtime enforcement: even if the agent's pattern-matching of operator words slips, the gate catches it. See Rule 7 of `rules/core/intent-capture-required.md`.

Select the subagent based on `category` and scope. See `references/execution-routing.md` for the full decision tree. Summary:

| category | scope | subagent |
|---|---|---|
| `research` | any | `Explore` / general-purpose Sonnet |
| `feature`, `bug`, `refactor` | ≤ 3 files, no new control-flow | `implementer-haiku` |
| `feature`, `bug`, `refactor` | medium, tests/integrations | `implementer` |
| `feature`, `bug`, `refactor` | domain expertise required | `agent-architect` |
| `meta` | plugin meta-work | main-direct (kill-switch path) |

Pass the full confirmed intent JSON as context. Include citations to applicable rules (`no-hardcoded-magic`, `secrets-and-pii`, etc.).

After the subagent returns, the audit chain runs: `test-engineer` → `code-reviewer` → `security-auditor`.

If the operator adds a new ask mid-execution: interrupt the subagent, return to Step 2 with a new intent object, resume only after the new intent is confirmed.

## Anti-Rationalizations

| Excuse | Reality |
|---|---|
| "The ask is simple, no need to grill" | Simple asks are ambiguous too. One scope question takes 10 seconds. |
| "I already know what they mean" | You have training data; they have context. Ask. |
| "The operator wants speed, not process" | Speed without confirmation produces rework. The gate is the speed optimization. |
| "It's a one-liner fix" | One-liner fixes introduce the most regressions. Confirm scope. |

## Red Flags

- About to run `Edit`, `Write`, or mutating `Bash` without a `confirmed` intent JSON in the conversation
- Operator message contains action verbs and you have not asked a single grilling question
- Grilling loop has 0 entries in `clarifications[]` for a genuinely ambiguous ask
- `status` is `draft` or `ready_for_confirmation` but you are already looking at files to edit

## Verification

```bash
# Confirm schema parses
python -c "import json; json.load(open('skills/intent-capture/references/intent-schema.json'))"

# Confirm references exist
ls skills/intent-capture/references/

# Confirm no Spanish in SKILL.md
grep -E "\b(de la|el |que|y |con |para )\b" skills/intent-capture/SKILL.md | wc -l
# Expected: 0
```
