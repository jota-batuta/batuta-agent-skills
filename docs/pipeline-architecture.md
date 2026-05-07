# batuta-agent-skills — Pipeline Architecture

Generated: 2026-05-07 | Commit: 753ca22 | Branch: feat/codebase-flow-mapper-IC-014

---

## Diagram 1 — System View

Six pipeline phases that make up the user journey from installation to KB sync. Cylinder nodes are persistent data stores.

```mermaid
flowchart TB
    subgraph INSTALL["Phase 0 - Installation"]
        A1["Marketplace install or git clone"]
        A2["hooks.json registered with Claude Code"]
        A1 --> A2
    end

    subgraph SESSION["Phase 1 - Session Start"]
        B1["session-start.sh"]
        B2[("Obsidian Vault")]
        B3["Uncommitted docs surfaced via git status"]
        B1 --> B2
        B1 --> B3
    end

    subgraph INTENT_PHASE["Phase 2 - Per-Turn Intent Gate"]
        C1["clear-intent-marker.sh fires on UserPromptSubmit"]
        C2["intent-capture skill"]
        C3["Tier assignment: trivial skips grill, standard grills"]
        C4[(".intent-and-routing-confirmed-ISO marker")]
        C1 --> C2
        C2 --> C3
        C3 --> C4
    end

    subgraph EXEC_PHASE["Phase 3 - Delegation"]
        D1["delegation-guard.sh and pre-edit-intent-gate.sh"]
        D2["Main Agent - orchestration only"]
        D3["implementer or implementer-haiku"]
        D4["agent-architect - builds project-local specialists"]
        D1 --> D2
        D2 --> D3
        D2 --> D4
    end

    subgraph AUDIT_PHASE["Phase 4 - Audit Chain"]
        E1["test-engineer"]
        E2["code-reviewer"]
        E3["security-auditor"]
        E1 --> E2
        E2 --> E3
    end

    subgraph KB_PHASE["Phase 5 - KB Sync"]
        F1["git commit"]
        F2["post-commit-kb.sh"]
        F3["kb-pipeline agent"]
        F1 --> F2
        F2 --> F3
    end

    A2 --> B1
    A2 --> C1
    B2 --> D2
    C4 --> D1
    D3 --> E1
    D4 --> E1
    E3 --> F1
    F3 --> B2
```

---

## Diagram 2 — Module Internals

Four source modules. Bold-bordered nodes are entry points called from other modules. Edges show dependency and invocation paths.

```mermaid
flowchart LR
    classDef entrypoint stroke-width:3px

    subgraph HOOKS_MOD["hooks/ - 8 shell scripts"]
        H1["session-start.sh"]:::entrypoint
        H2["clear-intent-marker.sh"]:::entrypoint
        H3["delegation-guard.sh"]:::entrypoint
        H4["pre-edit-intent-gate.sh"]:::entrypoint
        H5["pre-write-skill-gate.sh"]
        H6["pre-write-agent-gate.sh"]
        H7["pre-task-routing-gate.sh"]:::entrypoint
        H8["pr-merge-guard.sh"]:::entrypoint
    end

    subgraph SKILLS_MOD["skills/ - 34 skills, key ones shown"]
        S1["intent-capture"]:::entrypoint
        S2["batuta-skill-authoring"]:::entrypoint
        S3["batuta-agent-authoring"]:::entrypoint
        S4["batuta-project-hygiene"]:::entrypoint
        S5["using-agent-skills - skill router"]:::entrypoint
        S6["research-first-dev"]
        S7["code-graph"]
        S8["kb-end-session"]
        S5 --> S1
        S5 --> S2
        S5 --> S3
        S5 --> S4
    end

    subgraph AGENTS_MOD["agents/ - 9 agents"]
        AG1["implementer - Sonnet"]:::entrypoint
        AG2["implementer-haiku - Haiku"]:::entrypoint
        AG3["code-reviewer - Sonnet"]:::entrypoint
        AG4["test-engineer - Sonnet"]:::entrypoint
        AG5["security-auditor - Sonnet"]:::entrypoint
        AG6["agent-architect - Sonnet"]:::entrypoint
        AG7["kb-pipeline - Sonnet"]:::entrypoint
        AG6 --> AG1
        AG1 --> AG3
        AG1 --> AG4
        AG1 --> AG5
    end

    subgraph RULES_MOD["rules/ - 12 rules"]
        R1["intent-capture-required"]:::entrypoint
        R2["skill-authoring-required"]
        R3["agent-authoring-required"]
        R4["research-first-citations"]
        R5["code-style"]
        R6["secrets-and-pii"]
    end

    H2 --> S1
    S1 --> H4
    S1 --> H7
    S2 --> H5
    S3 --> H6
    R1 --> S1
    R2 --> S2
    R3 --> S3
    R4 --> AG1
    R5 --> AG1
    R6 --> AG1
    S1 --> AG1
    S1 --> AG2
    S1 --> AG6
    S6 --> S7
    AG7 --> S8
```

---

## Diagram 3 — Data Lineage

Cylinder nodes are data stores. Labeled edges show which module reads, writes, or deletes each store. Flagged nodes indicate ownership conflicts or duplicate sources of truth.

```mermaid
flowchart TB
    subgraph EPHEMERAL["Ephemeral Markers - .claude/"]
        D1[(".intent-and-routing-confirmed-ISO")]
        D2[(".authoring-marker-skill-ISO")]
        D3[(".authoring-marker-agent-ISO")]
    end

    subgraph DISCOVERY["Discovery Docs - docs/"]
        D4[("docs/intents/IC-NNN.md")]
        D5[("docs/sessions/YYYY-MM-DD.md")]
        D6[("docs/plans/active/slug.md")]
    end

    subgraph KB_STORES["KB Stores"]
        D7[("Obsidian Vault<br/>decisions, gotchas, playbooks")]
        D8[("Code Graph Cache<br/>codebase-memory-mcp")]
    end

    IC_SK["intent-capture skill"] -->|writes| D1
    IC_SK -->|writes standard tier only| D4
    CI_H["clear-intent-marker.sh"] -->|deletes| D1
    IG_H["pre-edit-intent-gate.sh"] -->|reads| D1
    TG_H["pre-task-routing-gate.sh"] -->|reads| D1

    SKA_SK["batuta-skill-authoring"] -->|writes| D2
    AGA_SK["batuta-agent-authoring"] -->|writes| D3
    SG_H["pre-write-skill-gate.sh"] -->|reads| D2
    AGG_H["pre-write-agent-gate.sh"] -->|reads| D3

    KBE_SK["kb-end-session skill"] -->|writes| D5
    SAV_SK["save-plan skill"] -->|writes| D6
    SS_H["session-start.sh"] -->|reads| D4
    SS_H -->|reads| D5
    SS_H -->|reads| D6
    SS_H -->|reads| D7

    KB_P["kb-pipeline agent"] -->|writes| D7
    SETUP_T["setup-code-graph.sh"] -->|writes| D8
    IMPL_A["implementer agent"] -->|reads| D8
    CG_SK["code-graph skill"] -->|reads| D8
```

---

## Analysis

| Severity | Finding | Type | Detection |
|---|---|---|---|
| HIGH | `.intent-and-routing-confirmed-ISO` has dual ownership | Ownership conflict | Written by `intent-capture`, deleted by `clear-intent-marker.sh` — two modules mutate the same file family |
| MEDIUM | Session context read from two sources | Duplicate source of truth | `session-start.sh` reads both `docs/sessions/*.md` AND Obsidian Vault for session history — they can diverge |
| MEDIUM | Intent data duplicated across two stores | Duplicate source of truth | `docs/intents/IC-NNN.md` (standard tier) records the same intent that `docs/sessions/*.md` summarizes at slice close |
| LOW | `hooks/` has 8 scripts — above the 7-function split threshold | Oversized module | 8 hook scripts serve 5 distinct event types; grouping by event type would yield 3 smaller modules |
| LOW | `batuta-status`, `kb-backfill`, `source-driven-development`, `browser-testing-with-devtools`, `context-engineering`, `idea-refine` have no auto-triggers in CLAUDE.md | Orphaned skills | Public skills with no MUST-trigger declaration — accessible only by explicit slash command |
| INFO | `using-agent-skills` routes to itself via `intent-capture` which re-invokes routing | Cycle risk | `using-agent-skills` → `intent-capture` → routing decision → possibly `using-agent-skills` again on ambiguous input |

---

## Recommendations

1. **Ownership conflict on intent markers** — designate `intent-capture` as the sole owner of `.intent-and-routing-confirmed-*` files. Rename the clear script's responsibility to `clear-stale-markers` and make it only delete markers older than the current turn timestamp, not all markers blindly. This makes the lifecycle explicit: intent-capture creates, clear-stale-markers prunes, gates read-only.

2. **Duplicate session sources of truth** — choose one canonical source for session history. Option A: make `session-start.sh` read only from the Obsidian Vault (KB is the truth, docs/sessions/ is the local draft). Option B: make `kb-pipeline` write only when `kb_pipeline_enabled: true` and have `session-start.sh` fall back to `docs/sessions/` when vault is unreachable. Currently both are read unconditionally and can produce conflicting context.

3. **Intent data duplication** — `docs/intents/IC-NNN.md` and the slice-close session journal entry both record the same intent. Keep the intent doc as the canonical audit trail (it has the grill Q&A); make the session journal entry a one-line reference (`See IC-NNN`) rather than a summary.

4. **Hooks module split** — reorganize `hooks/` into three sub-files by event type: `lifecycle/` (session-start, clear-intent-marker), `write-guards/` (delegation-guard, intent-gate, skill-gate, agent-gate), `commit-guards/` (pr-merge-guard, post-commit-kb). `hooks.json` stays flat; the directory split is for maintainability only.

5. **Orphaned skills** — add MUST-trigger declarations to `batuta-status` (end-of-session), `browser-testing-with-devtools` (any frontend change), and `context-engineering` (session-start when context > 60%). Remove or merge `source-driven-development` into `research-first-dev` — they share the same trigger and 80% of their procedure.
