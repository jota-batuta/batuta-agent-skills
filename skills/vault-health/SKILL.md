---
name: vault-health
description: Validate Obsidian vault structure: wikilink coverage, related: frontmatter, inbox staleness, and connectivity.
---

# vault-health

## Overview

The CLAUDE.md wikilink invariant states: "every vault file must include inline `[[wikilinks]]` and a `related:` frontmatter list." Without them the graph view and `research-first-dev` Step 1.5 lookups return zero results. This skill enforces that invariant on demand by running four checks against the live vault and reporting a pass/fail summary the operator can act on immediately.

## When to Use

- After `kb-backfill` populated the inbox
- After a batch of `kb-curate` promotions
- When `research-first-dev` Step 1.5 vault lookup returns zero results unexpectedly
- Monthly vault sweep (suggested by CLAUDE.md)
- Before sharing the vault with a new team member

Do NOT use for: repairing individual files (fix them manually then re-run this skill), promoting inbox entries (that is `kb-curate`), or backfilling legacy repos (that is `kb-backfill`).

## Process

### Step 1: Connectivity check

Read `~/.claude/kb-vault.json` to get `vault_root`:

```bash
vault_root=$(jq -r '.vault_root' ~/.claude/kb-vault.json 2>/dev/null)
```

Verify the path exists and is readable:

```bash
if [ ! -d "$vault_root" ]; then
  echo "FAIL: Vault unreachable. Check vault_root in ~/.claude/kb-vault.json"
  exit 1
fi
echo "OK: vault_root=$vault_root"
```

If connectivity fails, stop — the remaining steps are meaningless.

### Step 2: Wikilink coverage

Files missing at least one `[[wikilink]]` are graph islands — `research-first-dev` Step 1.5 cannot traverse them.

```bash
# Files missing [[wikilinks]] (no [[ anywhere in the file)
grep -rL '\[\[' "$vault_root" --include="*.md" \
  | grep -v "_templates/" | grep -v ".trash/"
```

Count the results. Target: **0**. Each file listed is a graph island that must have at least one inline `[[link]]` added.

### Step 3: `related:` frontmatter coverage

`related:` is a YAML list of all wikilinks used in the body. Without it, explicit graph edges are absent and `research-first-dev` Step 1.5 lookups return zero results even when inline links exist.

```bash
# Files missing related: in frontmatter
grep -rL '^related:' "$vault_root" --include="*.md" \
  | grep -v "_templates/" | grep -v ".trash/"
```

Count the results. Target: **0**. Each file listed needs a `related: ["[[...]]"]` frontmatter field added.

### Step 4: Inbox staleness

`_inbox/` files older than 7 days have not been curated and are blocking the drain protocol.

```bash
# Files in _inbox/ older than 7 days
find "$vault_root/_inbox" -name "*.md" -mtime +7 2>/dev/null
```

List every stale file. Run `kb-curate` to clear them. Files older than 30 days indicate `kb-curate` has stopped running.

**Output summary after all four steps:**

```
vault-health: vault_root=/path/to/vault
✓ Connectivity: OK
⚠ Wikilinks: 3 files missing [[wikilinks]]
⚠ related: frontmatter: 5 files missing related:
⚠ Inbox stale: 2 files older than 7 days
```

All four lines must show ✓ for the vault to be considered healthy.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I just ran kb-curate, the vault is fine" | kb-curate adds new entries but does not validate existing ones. Files curated before the wikilink invariant was enforced remain islands. |
| "Graph view in Obsidian shows connections" | Obsidian graph uses clickable inline links, not the `related:` field. `research-first-dev` Step 1.5 reads `related:` — a missing field returns zero results even when the graph view looks connected. |

## Red Flags

- Vault connectivity fails — stop, nothing else is meaningful
- More than 10% of vault files missing wikilinks — systematic gap, not isolated; fix the template or the agent that writes files
- Inbox has files older than 30 days — `kb-curate` has not been running; investigate the post-commit hook

## Verification

After fixing wikilink issues, re-run Step 2 to confirm the count drops to zero:

```bash
grep -rL '\[\[' "$vault_root" --include="*.md" \
  | grep -v "_templates/" | wc -l
# Expect: 0
```

After fixing `related:` gaps, re-run Step 3:

```bash
grep -rL '^related:' "$vault_root" --include="*.md" \
  | grep -v "_templates/" | wc -l
# Expect: 0
```
