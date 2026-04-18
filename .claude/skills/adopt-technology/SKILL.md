---
name: adopt-technology
description: Use when `/adopt-technology` is invoked. Evaluates library/tool/framework candidates against standardized criteria and produces a comparison table with clear recommendation.
---

# Adopt Technology

## Overview

Evaluate library, tool, or framework candidates using standardized criteria. Produce a comparison table and recommend the best option based on objective scores.

All output (report, table, justifications, recommendation) must be written in Japanese per project language policy.

## Procedure

### Step 1: Identify candidates

Ask the user (if not already specified):

- What capability is needed?
- Are there specific candidates to evaluate, or should you research options?

Research candidates using web search if needed. Aim for 2-4 candidates.

### Step 2: Evaluate against base criteria

| Criteria        | Description                                               | How to check                     |
| --------------- | --------------------------------------------------------- | -------------------------------- |
| **Popularity**  | Widely used (npm weekly downloads, GitHub stars)          | npm page, GitHub repo            |
| **Maintenance** | Actively maintained (issue close rate, release frequency) | GitHub insights, release history |
| **Feature fit** | Covers the features needed for this project               | Documentation, API surface       |

### Step 3: Add context-specific criteria

Based on the selection target, add relevant criteria. Examples:

- **Type safety** — Does it have TypeScript types (built-in or @types)?
- **Bundle size** — Is the package size reasonable for the use case?
- **Breaking changes** — History of breaking changes across major versions?
- **License** — Is the license compatible with the project?
- **Community** — Quality of documentation, Stack Overflow presence, examples?

Present the proposed criteria to the user for approval before evaluating.

### Step 4: Build comparison table

Evaluate each candidate and produce a table:

```markdown
| 評価基準     | Library A | Library B | Library C |
| ------------ | --------- | --------- | --------- |
| 普及度       | ⚪        | ⚪        | ×         |
| メンテナンス | ⚪        | ×         | ⚪        |
| 機能充足度   | ⚪        | ⚪        | ⚪        |
| 型安全性     | ⚪        | ⚪        | ×         |
| **合計 ⚪**  | **4**     | **3**     | **2**     |
```

- ⚪ = 基準を満たす
- × = 基準を満たさない

**REQUIRED:** After the comparison table, output a detail section for each candidate with evidence:

```markdown
### Library A

- npm: 週間 1,200,000 DL ([npmjs.com/package/library-a](link))
- GitHub: ⭐ 15,200 / Issue消化率 85% / 最終リリース 2026-02-28
- ライセンス: MIT
- 所見: {各判定の根拠}
```

Include actual numbers, links, and dates. Do NOT omit this section.

### Step 5: Recommend

- Recommend the candidate with the most ⚪
- If tied, explain trade-offs and ask user to decide
- If the top candidate has critical × marks, flag the risk

### Step 6: Record decision

**REQUIRED:** After user approval, you MUST invoke `create-adr` skill to record the selection as an ADR. Do NOT skip this step. The evaluation is incomplete without a recorded decision.

## Quality Checklist

- [ ] At least 2 candidates evaluated
- [ ] Base criteria (popularity, maintenance, feature fit) always included
- [ ] Context-specific criteria discussed with user
- [ ] Each mark has brief justification
- [ ] Recommendation clearly stated with reasoning
- [ ] Decision recorded as ADR
