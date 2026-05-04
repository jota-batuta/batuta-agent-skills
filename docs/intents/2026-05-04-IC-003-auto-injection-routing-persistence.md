---
id: IC-003
status: confirmed
captured_at: 2026-05-04
confirmed_at: 2026-05-04
operator_id: jota-batuta
agent_version: claude-opus-4-7
category: feature
related_pr: TBD
related_branch: feature/intent-gate-v4.3-auto-injection
related_plan: ""
---

# IC-003 — Auto-injection + routing declaration + intent persistence (v4.3)

## Original ask

> "No podemos depender de tu disciplina, es el punto de esto, no la tienes."

Followed by:

> "Esta rule es 100% efectiva — seguimos dependiendo de tu disciplina al momento de usar subagentes o de que yo te lo declare. Eso tiene que estar como parte del scope. Si yo te pido una tarea me debes decir uso o no uso subagentes, tu recomendación, y sobre eso yo trabajar."

> "Estos IC están quedando almacenados? Tienen que quedar dentro del proyecto, son parte principal del contexto y de las ADR y del desarrollo."

## Refined intent

Three combined improvements that close the remaining discretion gaps in the intent-capture gate:

1. **Auto-injection** — `clear-intent-marker.sh` (UserPromptSubmit) emits a system-reminder via `hookSpecificOutput.additionalContext` that authoritatively triggers `intent-capture` every operator turn. Moves from reactive blocking (hook frees tool when missing marker) to proactive instruction (agent receives explicit direction before the first tool call).
2. **Routing declaration protocol** — Before any tool call, the agent MUST declare to the operator (in plain language) whether it will use subagents (which ones, why) or main-direct, and wait for explicit approval. Closes the gap where the agent picks routing silently.
3. **Intent persistence** — Step 5 of intent-capture now writes BOTH the empty marker AND a versioned record at `docs/intents/<YYYY-MM-DD>-<id>-<slug>.md`. Confirmed intents become first-class development artifacts, equivalent to ADRs.

## Scope

### In
- `hooks/clear-intent-marker.sh` — emit JSON with `hookSpecificOutput.additionalContext` (preserves marker delete from v4.2)
- `rules/core/intent-capture-required.md` — Rule 6 (auto-injection), Rule 7 (routing declaration), Rule 8 (persistence)
- `skills/intent-capture/SKILL.md` — Step 1 references the system-reminder as the canonical trigger; Step 5 dual-write (marker + intents file); Step 6 demands routing declaration
- `CLAUDE.md` (project) — enforcement v4.2 → v4.3 with sections on routing-declaration and persistence
- `~/.claude/CLAUDE.md` (global) — MUST-C bumped to v4.3 + new MUST-D (routing-declaration) + new MUST-E (persistence)
- `.claude-plugin/plugin.json` — version 4.2.0 → 4.3.0
- `docs/intents/README.md` — convention doc explaining format and lifecycle
- `docs/intents/<3 backfilled records>.md` — IC-001, IC-002, IC-003

### Out
- No new slash command
- No changes to `pre-edit-intent-gate.sh` or `delegation-guard.sh`
- No automatic archiving of rejected/draft intents (only `confirmed` reaches `docs/intents/`)
- No JSON schema bump (existing `references/intent-schema.json` still valid)

## Acceptance

- `clear-intent-marker.sh` emits valid JSON with `hookSpecificOutput.additionalContext` on every UserPromptSubmit
- Reminder text covers three cases: action request / continuation confirmation / read-only question
- Rules 6, 7, 8 documented with the §A.4 inviolable-rules format
- SKILL.md Step 5 documents the dual-write
- SKILL.md Step 6 explicitly demands routing declaration before any tool call
- `docs/intents/` exists with `README.md` and 3 backfilled records (IC-001, IC-002, IC-003)
- `plugin.json` at 4.3.0
- PR created against main, not merged

## Routing declaration

| Trabajo | Quién | Por qué |
|---|---|---|
| `hooks/clear-intent-marker.sh` (modify) | Subagent (`implementer`) | Kill-switch path — `delegation-guard.sh` blocks main on `hooks/*.sh` |
| `rules/core/intent-capture-required.md` | Main-direct | Plugin meta-work, not kill-switch |
| `skills/intent-capture/SKILL.md` | Main-direct | Same |
| `CLAUDE.md` (project + global) | Main-direct | Exempt paths |
| `.claude-plugin/plugin.json` (version bump) | Main-direct | Exempt match (`*/plugin.json`) |
| `docs/intents/*.md` (README + 3 backfilled records) | Main-direct | `docs/**` exempt |

## Outcome

(To be filled on merge.)

## Original JSON

```json
{
  "asks": [{
    "id": "IC-003",
    "original_text": "no podemos depender de tu disciplina + el routing también es discrecional + los IC tienen que persistirse",
    "refined_text": "v4.3 con tres mejoras combinadas: (1) UserPromptSubmit auto-injection forzando grill, (2) routing declaration protocol, (3) persistencia de intents en docs/intents/ del proyecto — los IC son artefactos de primer nivel como ADRs.",
    "scope": {
      "in": [
        "hooks/clear-intent-marker.sh — emisión JSON con additionalContext",
        "rules/core/intent-capture-required.md — reglas 6, 7, 8",
        "skills/intent-capture/SKILL.md — Step 1 system-reminder, Step 5 dual-write, Step 6 routing declaration",
        "CLAUDE.md proyecto + global — v4.3, MUST-D, MUST-E",
        ".claude-plugin/plugin.json — 4.3.0",
        "BACKFILL: docs/intents/ + 3 archivos",
        "docs/intents/README.md"
      ],
      "out": [
        "No slash command nuevo",
        "No cambio a pre-edit-intent-gate.sh ni delegation-guard.sh",
        "No archivado automático de intents rechazados",
        "No bump de schema JSON"
      ]
    },
    "acceptance": [
      "clear-intent-marker.sh emite JSON con additionalContext",
      "Reminder cubre action/continuation/read-only",
      "Rule 6, 7, 8 documentadas",
      "SKILL.md Step 5 dual-write, Step 6 routing declaration",
      "docs/intents/ con README y 3 backfilled records",
      "plugin.json a 4.3.0",
      "PR creado, no mergeado"
    ],
    "category": "feature",
    "priority": "high",
    "clarifications": [
      {"question": "Confiar en disciplina del agente?", "answer": "No — mecanismo externo + routing declaration"},
      {"question": "Usás subagent para este PR?", "answer": "Sí, implementer para hooks/*.sh (kill-switch). Main-direct para todo el resto."},
      {"question": "Los IC quedan almacenados?", "answer": "No estaban — ahora se persisten obligatoriamente a docs/intents/ como parte del Step 5. Es regla 8 nueva."}
    ]
  }],
  "metadata": {
    "operator_id": "jota-batuta",
    "agent_version": "claude-opus-4-7"
  },
  "status": "confirmed"
}
```
