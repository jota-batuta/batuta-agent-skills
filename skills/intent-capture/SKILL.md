---
name: intent-capture
description: Use when the operator describes any concrete work to execute — edits, writes, commands, or changes to files, repos, or configs.
attribution: Grilling pattern derived from mattpocock/skills/grill-with-docs (https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)
---

# intent-capture

## Overview

**The agent NEVER executes work before capturing a confirmed intent.** Operators release ideas progressively and ambiguously. Acting on the first bullet produces rework. This skill enforces: detect tier → (grill if standard) → capture → present → confirm intent+routing in ONE block → execute, producing a JSON object conformant to `references/intent-schema.json` as the execution contract.

**v4.5 changes vs v4.4**:
- **Trivial tier** with mechanical threshold skips the grill for cosmetic / atomic changes.
- **Single combined confirmation** — intent + routing presented together, approved with one "dale", recorded in a single combined marker `.intent-and-routing-confirmed-<ISO>`. Halves round-trips.
- **Discovery commits bundle at slice close** — `docs/intents/<id>.md` is written immediately but committed bundled with the slice's code, not as a standalone commit (see Lever 4 of `docs/adr/0014-v4.5-intent-capture-slim.md`).

## When to Use

**Trigger on any operator message that requests concrete action**: verb in imperative, request to change files/repos/configs, feature description, bug report, or refactor ask.

**Do NOT trigger on**:
- Read-only questions ("what does X do?", "explain Y", "show me Z")
- Simple confirmations to an already-emitted intent ("yes", "go ahead", "ok")
- Mid-stream corrections to an intent in progress (merge into existing batch)

## Process

### Step 1: Detect + assign tier

Identify whether the operator message is an action request or read-only. If read-only → exit, answer directly. If action → proceed to Step 1b (tier).

**Per-turn invariant (v4.6):** every operator turn arrives with a clean slate —
`clear-intent-marker.sh` invalidated any prior marker and injected a routing
classifier (~25 tokens). The agent classifies (read-only vs action), resolves
the six dimensions (objective, done, scope, constraints, reversibility, safety)
from code/context, proposes what it can, and asks only what it cannot derive.
The operator validates — never fills from scratch. Short confirmations of an
intent already in progress ("sí", "dale", "procedé") continue Step 5.

#### Step 1b: Tier assignment (trivial vs standard)

Assign `tier: "trivial"` if and only if **ALL FIVE** conditions hold:

1. ≤3 files touched
2. ≤20 LOC changed in total
3. No new control flow (no new `if` / `for` / `while` / `try` / `async` introductions)
4. No new external dependency
5. Category in: `typo`, `copy`, `css`, `rename`, `comment`, `string-literal`, `version-bump`

If any condition fails → assign `tier: "standard"`. The agent declares the assigned tier in the captured JSON and (for trivial) cites which condition each ask satisfies.

Tool-portable invariant: opencode and other tools without hooks self-enforce this assignment by reading `rules/core/intent-capture-required.md`. The tier rule has no marker dependency — it is a pure protocol decision.

### Step 2: Grill (standard tier only — SKIPPED for trivial tier)

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
- `tier`: `"trivial"` or `"standard"` (assigned in Step 1b).
- `asks[]`: one item per distinct ask, each with `id`, `original_text`, `refined_text`, `scope`, `acceptance`, `priority`, `category`, `captured_at`, `clarifications[]` (the Q&A log; empty for trivial tier).
- `metadata`: session_id, operator_id, created_at, agent_version.
- `status`: set to `"ready_for_confirmation"`.
- `routing`: per-ask declaration of `subagent` (or `"main-direct"`) and `reason`. For trivial tier, this is forced to `"main-direct"` with reason `"trivial tier — atomic change, no subagent allowed"`.

### Step 4: Present (intent + routing in ONE block)

**Standard tier** — display the full JSON in a fenced markdown block AND a routing table (per file or per ask). Add one closing line: "Is this everything? On 'dale' I write the combined marker and execute."

**Trivial tier** — display a one-line summary instead of the full JSON. Format: `Trivial tier — {category}: {refined_text}. Files: {paths}. Routing: main-direct. ¿Dale?`. The full JSON is still constructed in memory (for the audit trail) but not displayed.

If the operator adds new asks → loop back to Step 2 (standard) or Step 1b (re-evaluate tier) for each new ask. Do not re-grill already-confirmed asks.

### Step 5: Confirm (single approval) + write combined marker

Wait for explicit confirmation ("yes, go ahead", "that's it", "proceed", "dale", or equivalent). The single confirmation covers BOTH intent and routing — there is no second approval. On confirm:

- Set `status: "confirmed"`, record `confirmed_at` and `confirmed_via`.
- **Write the combined marker** (Claude-Code-only enforcement; opencode skips this step): `<project-root>/.claude/.intent-and-routing-confirmed-<ISO-timestamp>` (UTC, RFC 3339, e.g. `.intent-and-routing-confirmed-2026-05-05T17:00:00Z`). Empty file. Gitignored. Valid until next UserPromptSubmit invalidates it. Consumed by both `pre-edit-intent-gate.sh` and `pre-task-routing-gate.sh`.
- **Persist the record (standard tier only)**: write `<project-root>/docs/intents/<YYYY-MM-DD>-<id>-<slug>.md` — markdown with YAML frontmatter (status, captured_at, confirmed_at, operator_id, agent_version, category, related_pr, related_branch, related_plan) and a narrative body (Original ask, Refined intent, Scope in/out, Acceptance, Routing declaration, Outcome, Original JSON in fenced block). The file is **written to disk immediately** but **NOT committed individually** — it bundles into the slice-close commit per Lever 4. See `docs/intents/README.md` for format.
- **Trivial tier**: NO `docs/intents/` file is created. The intent is recorded in the slice's session journal (Lever 4) as a one-line entry at slice close.

This JSON is the execution contract for the work that follows. Survival to compaction: for standard tier, the file is on disk at `docs/intents/<file>.md` (via `git status` — `session-start.sh` surfaces uncommitted files); for trivial tier, the brevity makes survival irrelevant (re-confirm on next turn is cheap).

### Step 6: Execute

With the combined marker written, execute per the routing declared in Step 4:

- **Trivial tier** → main-direct only. No subagent allowed. The agent runs the `Edit`/`Write`/`Bash` calls itself, then the audit chain at slice close.
- **Standard tier** → delegate per the routing table, or proceed main-direct as declared. Pass the full confirmed intent JSON as context. Include citations to applicable rules (`no-hardcoded-magic`, `secrets-and-pii`, etc.).

Routing decision tree (standard tier, see `references/execution-routing.md` for detail):

| category | scope | subagent |
|---|---|---|
| `research` | any | `Explore` / general-purpose Sonnet |
| `feature`, `bug`, `refactor` | ≤ 3 files, no new control-flow | `implementer-haiku` |
| `feature`, `bug`, `refactor` | medium, tests/integrations | `implementer` |
| `feature`, `bug`, `refactor` | domain expertise required | `agent-architect` |
| `meta` | plugin meta-work | main-direct |

After the subagent returns (or main-direct edits stage a diff), the audit chain runs: `test-engineer` → `code-reviewer` → `security-auditor`. Each returns NOT-APPLICABLE on a clean tree.

If the operator adds a new ask mid-execution: interrupt, return to Step 1b with a new intent object, resume only after the new intent is confirmed.

## Anti-Rationalizations

| Excuse | Reality |
|---|---|
| "The ask is simple, no need to grill" | Standard-tier simple asks are still ambiguous on scope. One scope question takes 10 seconds. The trivial tier exists for verifiable atomic changes — use it only when ALL FIVE conditions hold. |
| "I already know what they mean" | You have training data; they have context. Ask. |
| "The operator wants speed, not process" | Speed without confirmation produces rework. The trivial tier IS the speed optimization for atomic work; the standard-tier gate is the speed optimization for ambiguous work. |
| "It's trivial, I'll skip the marker too" | The marker write is the audit trail. Trivial tier skips the grill and the `docs/intents/` file, NOT the marker. |
| "It looks trivial but I'll re-classify it as trivial mid-flight" | Tier is assigned at Step 1b based on the operator's ask before any code is touched. Re-classifying after seeing the actual diff defeats the gate. |

## Red Flags

- About to run `Edit`, `Write`, or mutating `Bash` without a `confirmed` intent JSON in the conversation
- Operator message contains action verbs, tier was assigned `standard`, and you have not asked a single grilling question
- Grilling loop has 0 entries in `clarifications[]` for a genuinely ambiguous ask
- `status` is `draft` or `ready_for_confirmation` but you are already looking at files to edit
- About to commit `docs/intents/<id>.md` as a standalone commit (violates Lever 4 — bundle at slice close)
- Tier `trivial` declared but the ask doesn't satisfy ALL FIVE conditions (file count, LOC, control flow, dependency, category)

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
