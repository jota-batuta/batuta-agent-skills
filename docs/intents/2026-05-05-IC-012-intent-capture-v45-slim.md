---
id: IC-012
status: confirmed
captured_at: 2026-05-05
confirmed_at: 2026-05-05
operator_id: jota-batuta
agent_version: claude-opus-4-7
category: meta
related_pr: TBD
related_branch: TBD-feat/intent-capture-v45-slim
related_plan: docs/plans/active/2026-05-05-intent-capture-v45-slim.md
---

# IC-012 — intent-capture v4.5 — token & ceremony slim-down

## Original ask

> "todo esta funcionando bien pero tengo un problema operativo, la mision se cumple los bucles se dan, pero 1. demasiado verboso lo que hace que consuma demasiados tokens 2. demasiados loops de validacion propone el esquema y el enrutamiento y me me pide doble validacion lo que hace que el proceso sea lento, 3. lo que es un fix corto lo esta corriendo por todo el tunel se que dijimos que nada era trivial pero es momento de suavizar un poco el comportamiento"

Then expanded twice in the same turn:

> "hay otra cosa que esta consumiendo mucho y es el commit con cada accion es excesivo y muchos son fases de discovery"
> "que pasa si entre compatacion quedan intents?"

And the binding constraint:

> "debe quedar interoperable con opencode"

## Refined intent

Cut token cost and ceremony of the v4.4 intent + routing gate by four bundled levers, while preserving survival-after-compaction, runtime enforcement (Claude Code), audit trail in `docs/intents/`, and full opencode interop.

The four levers:

1. **Slim auto-injected reminder** in `clear-intent-marker.sh` from ~600 to ~100 tokens (Claude-Code-only).
2. **Combined intent + routing marker** — single marker `.intent-and-routing-confirmed-<ISO>`, single confirmation. Old markers honored for one release cycle.
3. **Trivial tier in `intent-capture`** — mechanical threshold (≤3 files / ≤20 LOC / no new control flow / no new dep / category in typo|copy|css|rename|comment|string-literal|version-bump). On match: skip grill, one-line confirmation, no `docs/intents/` file, forced main-direct routing.
4. **Bundle discovery commits at slice close** — intent/plan/session files written immediately to `docs/` but not committed individually; bundled into the slice-close commit alongside code.

## Scope

### In

- `hooks/clear-intent-marker.sh` — slim reminder + new marker glob in cleanup loop.
- `hooks/pre-edit-intent-gate.sh` — accept combined marker + legacy markers.
- `hooks/pre-task-routing-gate.sh` — accept combined marker + legacy markers.
- `skills/intent-capture/SKILL.md` — trivial tier branch, combined-marker writes, integrated routing in Step 5.
- `rules/core/intent-capture-required.md` — v4.5 rewrite: combined marker, trivial tier, deferred commit, Tool-portable vs Claude-Code-specific subsection.
- `~/.claude/CLAUDE.md` — Intent capture section + Git section update.
- `CLAUDE.md` (project) — v4.4 → v4.5 bump in intent-capture (enforced) subsection.
- `AGENTS.md` (cross-tool) — v4.5 protocol with MUST/NEVER imperative tone, Tool-portable vs Claude-Code-specific boundary explicit.
- `.opencode/agents/AGENTS.md.template` — alignment if it diverges.
- `docs/adr/0014-v4.5-intent-capture-slim.md` — new ADR.

### Out

- Audit chain restructuring (`agents/test-engineer.md`, `agents/code-reviewer.md`, `agents/security-auditor.md`).
- `kb-pipeline` / `post-commit-kb.sh` — unaffected by upstream commit-volume change.
- Other gates (skill-authoring, agent-authoring, rule-authoring, delegation-guard, pr-merge-guard).
- Backwards-compatibility shim beyond one release cycle (legacy markers removed in v4.6).

## Acceptance

- Reminder heredoc ≤120 tokens; auto-injection still triggers correct intent-capture invocation.
- Combined marker recognized by both gates; legacy markers still honored.
- Trivial-tier action executes with no grill, no `docs/intents/` file; standard-tier action keeps full grill but with collapsed single confirmation.
- A complete slice produces ≤3 commits.
- `docs/intents/<id>.md` survives compaction (file on disk; `session-start.sh` surfaces via `git status`).
- `bash tests/v2.5-validators/run.sh` exits 0 after rule renumbering.
- Opencode session against this repo: protocol shape matches Claude Code's behavior; `docs/intents/` file created on standard tier and absent on trivial tier.
- AGENTS.md uses MUST/NEVER imperative language with explicit Tool-portable vs Claude-Code-specific boundary.

## Routing declaration

| Trabajo | Quién | Por qué |
|---|---|---|
| Persistir plan a `docs/plans/active/` | Main-direct (Write) | `docs/**` exempt, mecánico |
| Escribir intent doc IC-012 + intent marker | Main-direct (Write) | `docs/**` y `.claude/**` exempt |
| Lever 1: slim reminder en `clear-intent-marker.sh` | Main-direct (Edit) | Cambio mecánico de heredoc, no nueva lógica |
| Lever 2: combined-marker en 3 hooks | Main-direct (Edit) | Plumbing de glob/marker, no nueva lógica de control |
| Lever 3: trivial tier en `SKILL.md` | Main-direct (Edit) | Es plugin meta-work (skill protocol), main retains per CLAUDE.md |
| Lever 3+2 alignment: rewrite rule file | Main-direct (Edit) | Rules son plugin meta-work, main retains |
| Lever 4: actualizar `~/.claude/CLAUDE.md` y project `CLAUDE.md` | Main-direct (Edit) | `**/CLAUDE.md` exempt, plugin meta-work |
| Update `AGENTS.md` cross-tool | Main-direct (Edit) | Plugin meta-work; consistency con rule file que también escribe main |
| Crear ADR 0014 | Main-direct (Write) | `docs/**` exempt, plugin meta-work |
| Validators estáticos | Main-direct (Bash) | `tests/v2.5-validators/run.sh` |
| Audit chain post-staged-diff | **Subagents** automáticos: `test-engineer` → `code-reviewer` → `security-auditor` | Convención CLAUDE.md "After any staged diff, the audit chain runs unconditionally" |
| Bundled commit final + push + PR | Main-direct (Bash) | Cierre del slice, política Lever 4 |

## Outcome

TBD — to be filled in at slice close.
