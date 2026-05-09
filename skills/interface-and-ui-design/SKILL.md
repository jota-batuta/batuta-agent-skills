---
name: interface-and-ui-design
description: Design stable API contracts and production-quality frontend components. Use when designing endpoints, data models, or building frontend UIs that must survive consumer versioning and accessibility requirements.
---

# Interface and UI Design

## Avoid the AI Aesthetic

AI-generated UI has recognizable patterns. Avoid all of them:

| AI Default | Why It Is a Problem | Do Instead |
|---|---|---|
| Purple/indigo everything | Makes every app look identical | Use the project's actual color palette |
| Excessive gradients | Visual noise, clashes with most design systems | Flat or subtle gradients from the design system |
| Rounded everything (rounded-2xl) | Ignores corner-radius hierarchy in real designs | Consistent border-radius from the design system |
| Generic hero sections | Template layout with no connection to actual content | Content-first layouts |
| Lorem ipsum-style copy | Hides layout problems real content reveals (length, wrapping, overflow) | Realistic placeholder content |
| Oversized padding everywhere | Destroys visual hierarchy, wastes screen space | Consistent spacing scale |
| Stock card grids | Ignores information priority and scanning patterns | Purpose-driven layouts |
| Shadow-heavy / dark-mode-only | Competes with content; excludes light-mode users | Subtle or no shadows; support both modes |

## The One-Version Rule

If you own the infrastructure, you own the migration. Avoid forcing consumers to choose between multiple versions of the same dependency or API. Diamond dependency problems arise when different consumers need different versions. Design for a world where only one version exists at a time -- extend rather than fork.

## Branded Types for IDs (TypeScript)

```typescript
type TaskId = string & { readonly __brand: 'TaskId' };
type UserId = string & { readonly __brand: 'UserId' };

// Prevents accidentally passing a UserId where a TaskId is expected
function getTask(id: TaskId): Promise<Task> { ... }
```

## Input/Output Type Separation

```typescript
// Input: what the caller provides
interface CreateTaskInput {
  title: string;
  description?: string;
}

// Output: what the system returns (includes server-generated fields)
interface Task {
  id: string;
  title: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;
}
```

Never reuse the output type as the input type. Server-generated fields (id, timestamps, computed values) must not appear in input interfaces.

## WCAG 2.1 AA Checklist

Full checklist: `references/accessibility-checklist.md`. Before shipping any UI:

- [ ] All interactive elements reachable and operable via keyboard (Tab, Enter, Space, Escape)
- [ ] Focus order is logical; focus is never trapped (except in modals, which trap intentionally)
- [ ] Every interactive element without visible text has `aria-label` or `aria-labelledby`
- [ ] Form inputs have associated `<label>` elements (via `htmlFor`/`id`)
- [ ] Color contrast >= 4.5:1 for normal text, >= 3:1 for large text
- [ ] Color is never the sole indicator of state (add icons, text, or patterns)
- [ ] Images have meaningful `alt` text (or `alt=""` for decorative)
- [ ] Loading, error, and empty states all present and announced to screen readers (`role="status"`, `aria-busy`)
- [ ] Heading levels are sequential (no skipping h1 -> h3)
- [ ] Touch targets >= 44x44px on mobile
