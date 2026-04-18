---
name: analyze-rejections
description: Analyzes rejection/feedback patterns in tmp/rejections.jsonl. When 2+ similar entries are found, proposes a new rule for docs/rules/. Triggers proactively after capture-feedback or when PostToolUse hook notifies of a recorded rejection.
---

# Analyze Rejections

## When to Trigger

Proactively trigger when:

- The PostToolUse hook reports a rejection was recorded (additionalContext mentions rejections.jsonl)
- The capture-feedback skill has just recorded a new entry
- The user explicitly asks to analyze rejections

## Process

1. Read `tmp/rejections.jsonl`
2. Group entries by similarity:
   - Same or similar rejection reason
   - Same category (dependency-policy, implementation-patterns, etc.)
   - Related file patterns or code patterns
3. For groups with 2+ entries:
   a. Summarize the pattern
   b. Draft a rule in MUST/MUST NOT format following `docs/rules/template.md`
   c. Identify the target file in `docs/rules/` (or propose a new category file)
   d. Present the rule to the user:
   - Show the pattern detected
   - Show the proposed rule text
   - Ask: "このルールを docs/rules/{file} に追加してよいですか？"
     e. If approved:
   - Append the rule to the target file
   - Remove the processed entries from `tmp/rejections.jsonl`
     f. If rejected:
   - Keep entries in log (may be re-evaluated later)
   - Optionally mark entries as "reviewed" to avoid repeated proposals

## Rule Format

Follow `docs/rules/template.md`:

```markdown
## {Rule Name}

- **種別**: MUST / MUST NOT
- **理由**: {Derived from rejection/feedback pattern}

### 内容

{Specific rule description}
```

## Grouping Heuristics

- Exact same rejection reason → same group
- Same file path or file pattern → likely related
- Same tool (Edit vs Write) with similar reason → same group
- Keywords overlap in reasons → candidate for grouping
