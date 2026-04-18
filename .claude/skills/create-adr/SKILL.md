---
name: create-adr
description: Use when a technical decision is made or being discussed during implementation - such as choosing a library, architecture pattern, data model, API design, build tool, or any significant trade-off. Also use when `/create-adr` is invoked. Triggers proactively whenever you observe a decision with alternatives and consequences.
---

# Create ADR (Architecture Decision Record)

## Overview

Record significant technical decisions as ADR documents. This skill triggers both explicitly (`/create-adr`) and **proactively** when a technical decision emerges during conversation.

## When to Trigger Proactively

Invoke this skill when you observe ANY of these during implementation:

- Choosing between libraries, frameworks, or tools
- Deciding on an architecture pattern or data model
- Selecting an API design approach
- Making trade-offs (performance vs readability, simplicity vs flexibility)
- Changing existing conventions or patterns
- Introducing new dependencies
- Deciding on error handling strategies, auth approaches, or deployment patterns

**Do NOT trigger for:** trivial choices (variable names, formatting), decisions already documented in an existing ADR, or temporary/experimental code.

## Procedure

### Step 1: Detect existing ADRs

```bash
ls docs/adr/[0-9]*.md 2>/dev/null | sort -r | head -1
```

Extract the highest `NNNN` number. If none exist, start at `0001`.

### Step 2: Gather decision context

Identify from the conversation:

| Field | Source |
| --- | --- |
| **Title** | What was decided (concise, in Japanese) |
| **Context** | Why the decision was needed |
| **Alternatives** | What options were considered |
| **Decision** | What was chosen and why |
| **Consequences** | Positive, negative, and neutral impacts |

If any field is unclear, ask the user before proceeding.

### Step 3: Propose the ADR to the user

Present a summary to the user for approval:

```
ADR-NNNN: [タイトル]
Status: Accepted
Context: [背景の要約]
Decision: [決定内容の要約]
```

Wait for user approval or modifications before writing the file.

### Step 4: Write the ADR file

Use the template at `docs/adr/template.md` as the base structure.

- Filename: `docs/adr/NNNN-title-with-dashes.md` (NNNN = next sequential number, title in English kebab-case)
- Content: Written in **Japanese** (per project language policy)
- Date: Today's date in YYYY-MM-DD format
- Author: Ask the user, or use the git user name

### Step 5: Update the ADR index

Add an entry to the ADR list table in `docs/adr/README.md`.

## ADR Quality Checklist

- [ ] Context explains WHY the decision was needed (not just WHAT)
- [ ] At least one alternative was considered and documented
- [ ] Decision states the reasoning, not just the choice
- [ ] Consequences include both positive AND negative impacts
- [ ] Written in Japanese
- [ ] File number is sequential with no gaps
