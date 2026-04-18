---
name: investigating-code
description: Use when the user asks about how code behaves, what a function does, how a flow works, or why something happens — including questions without explicit "investigate" wording. Covers branching logic, multi-file flows, and cross-function behavior.
model: sonnet
effort: low
---

# investigating-code

## Overview

Code investigations must be grounded in primary sources and verified before presentation. Read the code, cite exact locations, draw a diagram when flow is non-linear, and dispatch the `investigation-reviewer` agent to verify before replying.

## When to Use

- "How does X work?" / "このXは何してる？" / "Xの処理を説明して"
- "Why does Y happen?" / "なんでYになるの？"
- Questions requiring flow tracing across files or functions
- Library or cloud-platform behavior questions (`cited_sources` are URLs)

## When NOT to Use

- Pure syntax questions ("what does `??=` do in TypeScript?")
- One-liner standard-library lookups
- Off-topic questions (style, history, scheduling)

## Investigation Process

1. **Identify target** — which file/function/flow?
2. **Read primary sources** — Read exact file(s). For library/cloud questions, WebFetch the canonical docs.
3. **Draft the output** using the template below.
4. **Detect complexity trigger**:
   - ≥2 defined functions/methods touched in the flow, OR
   - ≥1 conditional branch (if/switch/ternary/early-return/guard) that affects behavior.
5. **If triggered:** generate Mermaid per the selection rules, then dispatch the reviewer.
6. **If reviewer returns NEEDS_REVISION or FAIL:** revise ONCE using findings. No second loop.
7. **Return the final result.** Any unresolved findings go under `## Reviewer Notes`.

## Output Template (required minimum)

````markdown
## Summary
<2–4 sentence plain-language answer>

## Flow   <!-- only if complexity trigger fires -->
```mermaid
...
```

## Sources
- path/to/file.ts:42-58
- https://docs.example.com/api/foo
````

If residual reviewer findings remain:

```markdown
## Reviewer Notes
- [MAJOR] <finding verbatim>
```

## Mermaid Selection Rules

| Situation | Diagram |
| --- | --- |
| Conditional branching is the main story | `flowchart TD` |
| Function-to-function call order or timing is the main story | `sequenceDiagram` |
| Both matter | Include both, flowchart first |
| Linear single-function logic | No diagram |

## Reviewer Dispatch

Use the `Agent` tool:

- `subagent_type`: `investigation-reviewer`
- `description`: e.g. `Verify code investigation result`
- `prompt`: a single string containing the three required fields:

```
topic: <one-line description of what was investigated>

investigation_result:
<full Markdown output drafted above>

cited_sources:
- <file path with line range, or URL>
- ...
```

Rules:

- **One revision loop only.** After revising once, return.
- **If the reviewer reports an unreachable source (CRITICAL):** surface it to the user. Do not silently retry.
- **If the user said "skip review":** skip dispatch; add `## Reviewer Notes: Reviewer skipped per user request`.

## Red Flags — STOP

Any of these means you're about to ship unverified work:

- "This is simple enough — no citation needed."
- "I already read the file carefully — re-reading is overkill."
- "The reviewer is slow, I'll skip it just this once."
- "I'll paraphrase to save time" (without checking accuracy).
- "The original term is clear enough" (assume it isn't).

## Rationalization Table

| Excuse | Reality |
| --- | --- |
| "Too simple to verify" | If ≥1 branch or ≥2 functions, NOT too simple. Verify. |
| "I already read the code" | Reviewer catches misreadings that feel correct. That's the point. |
| "Reviewer is slow" | 15s of review avoids 15 minutes of user confusion. |
| "User will understand the jargon" | Assume not — explain domain-specific terms at first use. |
| "Revising twice would be safer" | Design caps at 1 loop. Add residual notes instead. |
| "The diagram shape is right — exact call site doesn't matter" | Call-site misplacement = MAJOR. Place each call at its real control-flow location by re-reading before drawing. |
| "These two branches look mutually exclusive" | Check for source comments or boolean independence. Concurrent branches → `opt` (independent). Mutually exclusive → `alt`. Don't infer from visual proximity. |
| "Once the function is called, its body runs unconditionally" | Top-level guard in the callee (e.g. `if (x.isBetween(...))`) must appear as a conditional in the diagram — not an unconditional edge. |
