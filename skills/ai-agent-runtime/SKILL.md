---
name: ai-agent-runtime
description: Design the runtime layer for a multi-tenant AI agent system -- durable orchestration via Temporal.io, observability with Langfuse audit trail, and autonomous heartbeat scheduling. Use after completing ai-agent-foundation.
---

# AI Agent Runtime

## 14 Required Audit Fields

Every LLM call must emit a trace containing all 14 fields. No field may be omitted -- they are the minimum for regulatory compliance.

| # | Field | Type | Notes |
|---|---|---|---|
| 1 | trace_id | string | Unique trace identifier |
| 2 | session_id | string | Workflow/conversation session |
| 3 | tenant_id | string | Tenant isolation |
| 4 | agent_name | string | Which agent produced this |
| 5 | model | string | LLM model used (e.g. "claude-sonnet-4-20250514") |
| 6 | input_tokens | number | Token usage -- input |
| 7 | output_tokens | number | Token usage -- output |
| 8 | latency_ms | number | End-to-end latency |
| 9 | decision | string | What the agent decided |
| 10 | confidence | number | Confidence score (0-1) |
| 11 | action_taken | string | What action was executed |
| 12 | outcome | string | Result of the action |
| 13 | error | string \| null | Error if any (null on success) |
| 14 | timestamp | Date | When the trace was created |

## Temporal.io Determinism Rules

These calls are **FORBIDDEN** in Workflow code (they break replay and cause silent corruption):

| Forbidden | Use Instead |
|---|---|
| `datetime.now()` / `Date.now()` / `new Date()` | `workflow.now()` |
| `Math.random()` / `crypto.randomUUID()` | `workflow.random()` or pass as Activity result |
| `fetch()` / `axios` / any HTTP call | Move to Activity |
| `fs.readFile()` / any file I/O | Move to Activity |
| `console.log()` with timestamps | `workflow.log()` |
| `process.env` access | Pass as Workflow input or Activity result |

**Workflow** = deterministic, replayable: control flow, state machines, timer waits, signal handling, retry policies.
**Activity** = non-deterministic, side effects: LLM calls, DB reads/writes, external APIs, file I/O, notifications.

## HITL Gate Pattern

Human-in-the-loop approval must use Temporal Signals or `workflow.wait_condition()` -- **never `time.sleep()` or polling loops**.

- Send approval request via Activity (side effect).
- Wait for Signal with a timeout: `workflow.condition(() => this.approved !== undefined, { timeout })`.
- On timeout: escalate via Activity. Do not silently succeed.
- Add a `signal_escalate` handler so operators can force-escalate without waiting for timeout.
- In autonomous mode, HITL gates must have escalation timeouts. In prompt-based mode, they may wait indefinitely.

## Idempotency Requirement

The agent must check state before acting. Every heartbeat may fire multiple times (cron retry, crash recovery). The idempotency key is the event/task ID, not the LLM response.

Pattern: query for existing processing record by `(entity_id, tenant_id)`. If found, return early with `already_processed`. If not, process and write the record atomically.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We can add crash recovery later" | Temporal's determinism constraint must be respected from the first line. Retrofitting requires a complete rewrite. |
| "HITL approval is an edge case" | HITL gates are structural -- Signal handlers can't be added to running Workflow Event History. Add before first deployment. |
| "datetime.now() in the Workflow is fine" | Any non-deterministic call breaks replay. Same workflow replayed at different time will diverge. |
| "We'll add observability after the first incident" | After the first incident is too late. Traces are the incident evidence. |
| "14 fields is too many, we'll start with 5" | The 14 fields are the minimum for regulatory compliance. Omitting any fails the audit. |
| "Confidence scoring is unreliable" | Imperfect confidence is better than no signal. Drift in average confidence is the primary early warning for model degradation. |
| "We'll decide between prompt-based and autonomous later" | Execution mode is structural -- it determines trigger mechanism. Architecture diverges at this choice. |
| "Idempotency is hard for LLM outputs" | The idempotency key is the event/task ID, not the LLM response. Check state before acting. |
| "If the agent crashes, the operator will restart it" | B2B unattended automation cannot depend on operator intervention. Crash recovery must be automatic. |

## Red Flags

- `datetime.now()`, `random()`, or any I/O directly in Workflow code (not Activity)
- HITL gate as `time.sleep()` instead of Signal wait
- No Workflow replay test
- LLM call without surrounding trace
- Trace missing any of the 14 required fields
- No drift alerting configured
- `tenant_id` absent from trace
- No documented execution mode in Agent spec
- No idempotency check before agent's first action per heartbeat
- Crash recovery not tested
- No SLA escalation for production agents

## Verification

- [ ] Workflow boundary documented (state vs Activity side effects)
- [ ] `execution_mode` flag present in Workflow input
- [ ] HITL gate uses Signal/wait_condition, not sleep
- [ ] Workflow replay test passes (crash recovery verified)
- [ ] No non-deterministic calls in Workflow code
- [ ] Every LLM call wrapped in Langfuse trace
- [ ] Trace contains all 14 required audit fields
- [ ] Drift detection configured on >= 2 metrics
- [ ] Decision trace queryable by operator
- [ ] Heartbeat cron schedule documented and active
- [ ] Idempotency check present before first action
- [ ] SLA escalation threshold configured
