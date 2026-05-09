# User Journey — BATUTA Agent Skills Plugin

> Diagnostic snapshot for the v5.x refactor. Shows the intended flow, enforcement gaps, and skill taxonomy misalignments.

---

## 1. Primary Hot Path (The Nine-Skill Loop)

Every user task enters here. Hooks enforce checkpoints at runtime — the prose-only skills have no machine enforcement.

```mermaid
flowchart TD
    START([User has a task]) --> ROUTE

    subgraph ROUTE_PHASE["Phase 0 — Route"]
        ROUTE["/using-agent-skills\nRoute to smallest skill"]
        H_ROUTE{{"Hook: pre-task-routing-gate\nSubagent routing classifier"}}
        ROUTE --> H_ROUTE
    end

    H_ROUTE -->|task spawned| INTENT_PHASE
    H_ROUTE -->|wrong model detected| BLOCKED_MODEL([Blocked: model-routing violation])

    subgraph INTENT_PHASE["Phase 1 — Intent"]
        INTENT["/intent-capture\nPending → Confirmed two-phase protocol"]
        H_EDIT{{"Hook: pre-edit-intent-gate\nBlocks all edits without confirmed intent"}}
        H_DELEGATE{{"Hook: delegation-guard\nBlocks model from writing confirmed markers"}}
        INTENT --> H_EDIT
        INTENT --> H_DELEGATE
    end

    H_EDIT -->|intent confirmed| CONTEXT_PHASE
    H_EDIT -->|no intent marker| BLOCKED_INTENT([Blocked: intent-capture-required])

    subgraph CONTEXT_PHASE["Phase 2 — Context"]
        CONTEXT["/context-engineering\nLoad minimum viable context"]
        H_SESSION{{"Hook: pre-session-context-gate\nValidate session context loaded"}}
        CONTEXT --> H_SESSION
    end

    H_SESSION --> RESEARCH_PHASE

    subgraph RESEARCH_PHASE["Phase 3 — Prior Art"]
        RESEARCH["/research-first-dev\nPrior art before code"]
        EVAL_R(["✓ SKILL.eval.yaml"])
        RESEARCH --- EVAL_R
        H_CITE{{"Hook: post-edit-citation-warn\nWarn on missing // Source: citations"}}
        RESEARCH --> H_CITE
    end

    H_CITE --> BUILD_PHASE

    subgraph BUILD_PHASE["Phase 4 — Build"]
        IMPL["/incremental-implementation\nVertical slicing — one slice at a time"]
        TEST["/test-driven-development\nRED → GREEN → REFACTOR"]
        IMPL --> TEST
    end

    TEST --> REVIEW_PHASE

    subgraph REVIEW_PHASE["Phase 5 — Review & Audit Chain"]
        REVIEW["/code-review-and-quality\nFive-axis gate"]
        A_TEST(["Agent: test-engineer\nGATE 1 — coverage"])
        A_REVIEW(["Agent: code-reviewer\nGATE 2 — five axes"])
        A_SECURITY(["Agent: security-auditor\nGATE 3 — OWASP scan"])
        REVIEW --> A_TEST --> A_REVIEW --> A_SECURITY
    end

    A_SECURITY --> SHIP_PHASE

    subgraph SHIP_PHASE["Phase 6 — Ship & Close"]
        GIT["/git-workflow-and-versioning\nAtomic commits, conventional format"]
        H_PR{{"Hook: pre-pr-create-guard\nVerify intents bundled"}}
        H_MERGE{{"Hook: pr-merge-guard\nBlock merge without audit chain + KB"}}
        CLOSE["/slice-close\nBundle → PR → session journal"]
        GIT --> H_PR --> H_MERGE --> CLOSE
    end

    CLOSE --> KB_PHASE

    subgraph KB_PHASE["Phase 7 — Knowledge Capture"]
        H_COMMIT{{"Hook: post-commit-kb\nJournal bullet + dispatch kb-pipeline"}}
        KB_PIPELINE(["Agent: kb-pipeline\nL0/L1 per-commit capture"])
        CURATE(["Agent: kb-curator\nL1 → L2/L3 batch promotion"])
        SESSION_END["/kb-end-session\nClose journal, trigger curation"]
        H_COMMIT --> KB_PIPELINE --> CURATE --> SESSION_END
    end

    SESSION_END --> END([Session complete — vault updated])

    style EVAL_R fill:#2a9d2a,color:#fff
    style BLOCKED_MODEL fill:#c0392b,color:#fff
    style BLOCKED_INTENT fill:#c0392b,color:#fff
```

---

## 2. SKILL.eval.yaml Coverage Gap

Only 5 of 50 skills have machine-verifiable acceptance criteria. The other 45 are prose-only — hook enforcement cannot reach inside them.

```mermaid
pie title SKILL.eval.yaml coverage (5 / 50 skills = 10%)
    "Has SKILL.eval.yaml" : 5
    "Missing SKILL.eval.yaml" : 45
```

### Skills WITH eval (green — hook-enforceable)

```mermaid
flowchart LR
    subgraph EVAL_YES["✓ Has SKILL.eval.yaml"]
        direction TB
        R[research-first-dev\nPhase 3 hot path]
        BA[batuta-agent-authoring\nAuthoring gate]
        BS[batuta-skill-authoring\nAuthoring gate]
        PH[batuta-project-hygiene\nBootstrap gate]
        LD[living-docs-maintenance\nPer-slice doc update]
    end

    subgraph EVAL_NO["✗ Missing SKILL.eval.yaml — prose only"]
        direction TB
        N1[intent-capture]
        N2[context-engineering]
        N3[incremental-implementation]
        N4[test-driven-development]
        N5[code-review-and-quality]
        N6[git-workflow-and-versioning]
        N7[slice-close]
        N8["+ 38 more skills"]
    end

    style EVAL_YES fill:#1a5c1a,color:#fff
    style EVAL_NO fill:#5c1a1a,color:#fff
```

---

## 3. Skill Taxonomy — All 50 Skills

```mermaid
mindmap
  root((BATUTA\nSkills Plugin\n50 skills))
    Hot Path
      using-agent-skills
      intent-capture
      context-engineering
      research-first-dev ✓EVAL
      incremental-implementation
      test-driven-development
      code-review-and-quality
      git-workflow-and-versioning
      slice-close
    Authoring Gates
      batuta-skill-authoring ✓EVAL
      batuta-agent-authoring ✓EVAL
      batuta-rule-authoring
    6-Layer AI Harness
      multi-tenant-connector-pattern
      rules-as-code-authoring
      memory-architecture-design
      durable-orchestration-temporalio
      observability-contract
      agent-heartbeat-autonomy
    Quality Axes
      debugging-and-error-recovery
      security-and-hardening
      performance-optimization
      code-simplification
    KB Pipeline
      batuta-kb-vault
      kb-backfill
      kb-curate
      kb-end-session
      vault-health
    Delivery
      ci-cd-and-automation
      shipping-and-launch
      documentation-and-adrs
      deprecation-and-migration
      living-docs-maintenance ✓EVAL
    Planning and Design
      spec-driven-development
      planning-and-task-breakdown
      idea-refine
      api-and-interface-design
      frontend-ui-engineering
      codebase-flow-mapper
    Compatibility Wrappers
      source-driven-development
      slice-open
      pr-prep
    Operational
      browser-testing-with-devtools
      save-plan
      batuta-status
      hooks-diagnose
      rules-import
      batuta-project-hygiene ✓EVAL
```

---

## 4. Hook Enforcement Timeline

Shows where the 14 hooks fire relative to the user journey. Gaps between hooks = unguarded zones.

```mermaid
timeline
    title Hook firing order — one user session
    section Session Start
        SessionStart : session-start.sh — vault context injection, hygiene auto-invoke
    section Intent Phase
        UserPromptSubmit : clear-intent-marker.sh — promote pending → confirmed markers
        PreToolUse Edit : pre-edit-intent-gate.sh — BLOCK if no confirmed intent
        PreToolUse Task : pre-task-routing-gate.sh — subagent routing classifier
        PreToolUse : delegation-guard.sh — block model from writing confirmed markers
        PreToolUse : pre-session-context-gate.sh — validate session context loaded
    section Authoring Gates
        PreToolUse Write skill : pre-write-skill-gate.sh — enforce batuta-skill-authoring marker
        PreToolUse Write agent : pre-write-agent-gate.sh — enforce batuta-agent-authoring marker
        PreToolUse Write feature : pre-write-feature-gate.sh — enforce batuta-project-hygiene marker
    section Ship Phase
        PreToolUse gh pr create : pre-pr-create-guard.sh — verify intents bundled
        Custom before merge : pr-merge-guard.sh — audit chain + KB required
    section Post-work
        PostToolUse Edit : post-edit-citation-warn.sh — warn on missing Source citations
        PostCommit : post-commit-kb.sh — journal bullet + dispatch kb-pipeline agent
        PostExit plan mode : post-exit-plan-mode.sh — persist plan to docs/plans/active/
```

---

## 5. Refactor Priority Map

```mermaid
quadrantChart
    title Skill refactor priorities
    x-axis Low Overlap --> High Overlap
    y-axis Low Missing Eval Impact --> High Missing Eval Impact
    quadrant-1 Refactor first — high impact, high overlap
    quadrant-2 Add eval — high impact, low overlap
    quadrant-3 Monitor — low impact, low overlap
    quadrant-4 Consolidate — high overlap, lower eval need
    intent-capture: [0.15, 0.92]
    context-engineering: [0.12, 0.85]
    incremental-implementation: [0.20, 0.80]
    test-driven-development: [0.18, 0.88]
    code-review-and-quality: [0.25, 0.78]
    git-workflow-and-versioning: [0.10, 0.70]
    slice-close: [0.22, 0.72]
    batuta-rule-authoring: [0.08, 0.65]
    source-driven-development: [0.85, 0.30]
    slice-open: [0.80, 0.28]
    pr-prep: [0.78, 0.25]
    security-and-hardening: [0.45, 0.55]
    performance-optimization: [0.40, 0.50]
    code-simplification: [0.42, 0.48]
    debugging-and-error-recovery: [0.30, 0.45]
    living-docs-maintenance: [0.15, 0.20]
    documentation-and-adrs: [0.50, 0.40]
    save-plan: [0.35, 0.35]
    idea-refine: [0.20, 0.30]
    codebase-flow-mapper: [0.15, 0.25]
```

---

## 6. Alignment Gaps Summary

```mermaid
flowchart TD
    subgraph GAPS["Identified misalignments vs. skill-building policy"]
        G1["1. 90% of skills have no SKILL.eval.yaml\nPrinciple: enforcement over prose"]
        G2["2. Compatibility wrappers (source-driven-dev, slice-open, pr-prep)\nhave no deprecation timeline or redirect markers"]
        G3["3. Quality axes skills (security, perf, simplification, debugging)\noverlap with code-review-and-quality but have no linking mechanism"]
        G4["4. Hot-path skills (intent-capture, context-engineering,\nincremental-impl, TDD, git, slice-close)\nare the highest-traffic but lowest eval coverage"]
        G5["5. 6-layer AI harness has zero eval files\ndespite being the most structurally complex skill group"]
        G6["6. batuta-rule-authoring is the only authoring gate\nwithout SKILL.eval.yaml"]
    end

    subgraph ACTIONS["Refactor actions by priority"]
        A1["P0 — Write SKILL.eval.yaml for 7 hot-path skills\n(all 9 minus research-first-dev and using-agent-skills)"]
        A2["P1 — Add SKILL.eval.yaml for batuta-rule-authoring\n(completes the authoring gate trio)"]
        A3["P2 — Mark wrappers deprecated in frontmatter,\nset removal target: v6.0"]
        A4["P3 — Add xref links from code-review-and-quality\nto quality-axes deep-dive skills"]
        A5["P4 — Write SKILL.eval.yaml for 6-layer harness\nstarting with multi-tenant-connector-pattern"]
    end

    G1 --> A1
    G6 --> A2
    G2 --> A3
    G3 --> A4
    G5 --> A5
    G4 --> A1
```

---

## Notes

- **Source of truth:** `user-settings/CLAUDE.md` — all hooks, agents, skills derive authority from it.
- **Skill anatomy spec:** `docs/skill-anatomy.md` — defines required sections and writing principles.
- **Current skill count:** 50 (target after wrapper removal: ~46).
- **Hooks enforced:** 14 shell scripts + hooks.json; gaps identified above in Phases 3–5.
- **Audit chain is sequential (ADR-0004):** test-engineer → code-reviewer → security-auditor — never parallel.
