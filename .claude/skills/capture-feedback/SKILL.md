---
name: capture-feedback
description: Proactively captures user feedback/corrections during conversation and records to tmp/rejections.jsonl for pattern analysis. Triggers when user corrects Claude Code's approach with phrases like "not that", "don't do", "instead do", "wrong approach".
---

# Capture Feedback

## Overview

Record user corrections and negative feedback about Claude Code's approach into `tmp/rejections.jsonl` for later pattern analysis. This skill triggers **proactively** when the user indicates a mistake or unwanted behavior.

## When to Trigger Proactively

Invoke this skill when the user provides correction or negative feedback, such as:

- "そうじゃない" / "違う" / "それはやめて"
- "〜しないで" / "〜ではなく〜して"
- "not that" / "don't do" / "instead do" / "wrong approach"

**Do NOT trigger for:**

- General questions or discussions
- Positive feedback
- Requests for new features (not corrections)

## Procedure

### Step 1: Read existing rejection log

```bash
mkdir -p tmp
touch tmp/rejections.jsonl
cat tmp/rejections.jsonl
```

If the file does not exist, create it.

### Step 2: Categorize the feedback

Identify from the conversation:

| Field           | Source                                                     |
| --------------- | ---------------------------------------------------------- |
| **Description** | What was wrong and what should have been done              |
| **Category**    | `dependency-policy`, `implementation-patterns`, or `other` |
| **Context**     | Relevant file path or code pattern                         |

### Step 3: Append a JSONL entry

Append one JSON line to `tmp/rejections.jsonl`:

```json
{
  "timestamp": "ISO 8601",
  "type": "feedback",
  "description": "Brief description of what was wrong and what's correct",
  "category": "dependency-policy | implementation-patterns | other",
  "context": "Relevant file or code context"
}
```

Use the current timestamp in ISO 8601 format (e.g., `2026-03-17T12:00:00+09:00`).

### Step 4: Check for patterns

After recording, count entries with the same `category`. If **2 or more similar entries** exist, suggest running the `analyze-rejections` skill to identify recurring patterns.

## Quality Checklist

- [ ] Description clearly states both the incorrect action AND the correct approach
- [ ] Category is one of the three allowed values
- [ ] Context references the relevant file or pattern
- [ ] Timestamp is in ISO 8601 format
- [ ] Entry is valid JSON appended as a single line
