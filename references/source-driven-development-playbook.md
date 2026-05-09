# Source-Driven Development — Reference Playbook

Companion to `skills/source-driven-development/SKILL.md`. Kept short; the skill itself is 18 lines.

---

## Source Hierarchy

Every framework-specific decision must trace to a source in this priority order:

| Priority | Source | Example |
|----------|--------|---------|
| 1 | Official documentation | react.dev, docs.djangoproject.com, symfony.com/doc |
| 2 | Official blog / changelog | react.dev/blog, nextjs.org/blog |
| 3 | Web standards references | MDN, web.dev, html.spec.whatwg.org |
| 4 | Browser/runtime compatibility | caniuse.com, node.green |

Not authoritative (never cite as primary): Stack Overflow, blog posts, AI-generated summaries, training data.

## Citation Format

In code comments:

```typescript
// React 19 form handling with useActionState
// Source: https://react.dev/reference/react/useActionState#usage
const [state, formAction, isPending] = useActionState(submitOrder, initialState);
```

In conversation:

```
I'm using useActionState instead of manual useState for the form submission state.
Source: https://react.dev/blog/2024/12/05/react-19#actions
```

Rules: full URLs, prefer deep links with anchors, quote the relevant passage for non-obvious decisions. If you cannot find documentation, flag it explicitly as UNVERIFIED.

## Key Rationalizations

| Rationalization | Reality |
|---|---|
| "I'm confident about this API" | Confidence is not evidence. Training data contains outdated patterns that look correct but break against current versions. Verify. |
| "Fetching docs wastes tokens" | Hallucinating an API wastes more. One fetch prevents hours of rework. |
| "I already know this library" | You know the version from your training cutoff. The user's `package.json` may pin a different version with a different API surface. |
| "The docs won't have what I need" | If the docs don't cover it, that's valuable information — the pattern may not be officially recommended. |
| "This is a simple task, no need to check" | Simple tasks with wrong patterns become templates. The user copies your deprecated handler into ten components before discovering the modern approach. |
