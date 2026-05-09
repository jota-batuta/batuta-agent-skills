---
name: batuta-project-hygiene
description: Bootstraps CLAUDE.md, doc skeleton (PRD/SPEC/ADR/plans/sessions), and GitHub repo. Use at session start or before SPEC.md/feature CLAUDE.md. Feature files NEVER at root. project-init | feature-init.
---

# Batuta Project Hygiene

## Mode Routing

| Mode | Trigger | What it does |
|---|---|---|
| `project-init` | `CLAUDE.md` missing + project markers present | Bootstrap rules file + doc skeleton + GitHub repo + first commit |
| `project-retrofit` | `CLAUDE.md` exists but doc skeleton incomplete | Silently add missing pieces (purely additive, no prompts) |
| `feature-init` | Operator describes a new feature | Create scoped subfolder with CLAUDE.md + SPEC.md, delegate to spec-driven-development |

## Feature Folder Convention

Record in `CLAUDE.md` under `## Feature folder convention`:

```markdown
## Feature folder convention

style: <feature-oriented | layered>
features-root: <path-template>
```

**Feature-oriented** (vertical slices): `features-root: src/<feature>/` -- code lives inside feature folder.

**Layered** (horizontal layers like `models/`, `services/`, `activities/`): `features-root: docs/features/<feature>/` -- code stays in existing layers; feature folders are docs-only.

Rule of thumb: if relocating code into `src/<feature>/` would require a PR touching >20 files purely to reorganize, the project is layered.

## Doc Skeleton Structure

Created by `project-init`, gap-filled by `project-retrofit`:

```
<project-root>/
├── CLAUDE.md
├── docs/
│   ├── PRD.md                          # Problem / Vision / Users / Success metrics / Non-goals / Constraints
│   ├── SPEC.md                         # Component map / Architecture summary / Cross-cutting constraints
│   ├── adr/0001-template-decision.md   # ADR format reference
│   ├── plans/active/                   # Current plan (from save-plan)
│   ├── plans/archive/                  # Shipped plans
│   └── sessions/                       # Session journals (from KB hooks)
```

## Feature-Init Steps

**Hard constraint**: feature SPEC.md and CLAUDE.md MUST live inside a subfolder, NEVER at project root.

**Input validation**: `<name>` must match `^[a-z0-9][a-z0-9-]{0,40}$`. Reject and re-prompt if not; do not sanitize.

1. **Read `## Feature folder convention`** from project CLAUDE.md to resolve target path. If missing or placeholder, auto-detect from project structure and back-fill.

2. **Create feature folder** at resolved path. Reject if it already exists.

3. **Create `<feature-folder>/CLAUDE.md`** -- feature-oriented variant includes Scope + Boundaries; layered variant includes Scope + Code map (table of which layer files implement the feature) + Boundaries.

4. **Delegate SPEC creation** to spec-driven-development, **explicitly overriding write target** to `<feature-folder>/SPEC.md`. If SPEC ends up at root, move it before committing.

5. **Commit**:
   ```bash
   git checkout -b feature/<name>
   git add <feature-folder>/
   git commit -m "feat(<name>): scaffold feature folder with CLAUDE.md and SPEC.md"
   ```

6. **Write authoring marker (MANDATORY)**:
   ```bash
   mkdir -p "$(git rev-parse --show-toplevel)/.claude" && \
     touch "$(git rev-parse --show-toplevel)/.claude/.authoring-marker-feature-$(date -u +%Y-%m-%dT%H-%M-%SZ)"
   ```
   Without this marker, subsequent feature CLAUDE.md creation is blocked by the gate hook. Valid for 60 minutes (mtime-based).

7. **Verify**: `<feature-folder>/CLAUDE.md` exists, `<feature-folder>/SPEC.md` exists, `git branch --show-current` returns `feature/<name>`, authoring marker present.

## KB Hook Installation

Runs during `project-init` step 4c (auto-apply, no prompt):

1. **Resolve vault path**: read `~/.claude/kb-vault.json` -> `.vault_root`. If missing, ask operator for absolute path and save globally.

2. **Client discovery**: scan `<vault_root>/clients/*/` for `_metadata.md`, present numbered menu. If operator picks existing client, use it. If new, collect full name / industry / country / slug and create `_metadata.md`.

3. **Project folder bootstrap**: create `<vault_root>/clients/<client>/projects/<project>/` with subfolders `sessions/`, `sprints/`, `decisions/`, `gotchas/`, `tasks/`.

4. **Create `.claude/kb-config.json`**:
   ```json
   {
     "enabled": true,
     "client": "<client>",
     "project": "<project>",
     "vault_root": "<absolute-path>",
     "session_slug_strategy": "branch-or-plan-or-daily"
   }
   ```

5. **Install hook**: copy `~/.claude/plugins/marketplaces/batuta-agent-skills/hooks/post-commit-kb.sh` to `.git/hooks/post-commit`. If existing hook has non-Batuta content, append instead of overwriting.

6. **Gitignore**: append `.claude/kb-config.json` to `.gitignore` (machine-specific path).

7. **Verify**: `test -f .git/hooks/post-commit && grep -q "post-commit-kb" .git/hooks/post-commit && test -f .claude/kb-config.json`

## Red Flags

- SPEC.md or CLAUDE.md for a feature ending up at project root (top failure mode)
- Creating feature folder without reading `## Feature folder convention` first
- Skipping authoring marker after scaffold commit
- Creating a feature folder at `src/<name>/` when style is recorded as `layered`
- Moving existing code as side-effect of feature-init (hygiene never moves code)
- Treating a technical layer name (`services/`, `activities/`) as a feature
