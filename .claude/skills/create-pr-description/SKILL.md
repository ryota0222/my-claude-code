---
name: create-pr-description
description: Use when running `/create-pr-description`, or when the user asks to write a PR description. Analyzes branch commits and generates a Japanese PR title and description with appropriate sections based on FE/BE detection. Does NOT create the PR - only proposes the content.
---

# Create PR Description Skill

Proposes a Japanese PR title and description based on the commits of the current branch. Does NOT create the PR.

## Procedure

### Step 1: Gather branch info

Run these in parallel:

```bash
# All commits since the base branch
git log main..HEAD --oneline

# Overview of the diff
git diff main...HEAD --stat

# Current branch name
git branch --show-current

# Remote state
git status

# Detect TODO comments inside the diff
git diff main...HEAD | grep -n "^+.*TODO"
```

### Step 2: Detect FE/BE

Decide based on file extensions, paths, and overall project layout:

| Signal | Classification |
| --- | --- |
| `.tsx`, `.jsx`, `.vue`, `.svelte`, `next.config`, `nuxt.config`, `vite.config`, `src/components/`, `src/pages/`, `public/` | **FE** |
| `.go`, `.py`, `.rb`, `.java`, `.rs`, `internal/`, `cmd/`, `api/`, `server/`, `migrations/`, `Dockerfile` | **BE** |
| `package.json`, `.ts`, `.js` | **Context-dependent** (FE if UI, BE if server-side) |
| Both present | **FE+BE** |

When in doubt, check the repo's README or `package.json` dependencies for the tech stack.

### Step 3: Generate the PR description

Use the format below. Analyze commits and summarize the **purpose and overview** of the change concisely.

#### FE format:

```markdown
## 概要
<!-- 変更の目的と概要を1-3行で記述 -->

## 変更内容
<!-- 主な変更点を箇条書きで記述 -->

## 画面キャプチャ
<!-- 変更した画面のスクリーンショットを貼付してください -->
| 画面名A | 画面名B |
|---------|---------|
|         |         |

## 備考（※TODOコメントがある場合のみ）
- `ファイルパス`: TODOコメントの内容
```

#### BE format:

```markdown
## 概要
<!-- 変更の目的と概要を1-3行で記述 -->

## 変更内容
<!-- 主な変更点を箇条書きで記述 -->

## 備考（※TODOコメントがある場合のみ）
- `ファイルパス`: TODOコメントの内容
```

### Step 4: Present the proposal

Show the PR title and description to the user. Do NOT run `gh pr create` or push.

## Rules

- PR title: within 70 characters, concise Japanese
- Do not just enumerate commit messages; summarize the **purpose** of the change
- The 概要 section explains *why* the change is needed
- The 変更内容 section lists technical changes as bullets
- For FE, always include the 画面キャプチャ section. Ask the user how many screens to include before deciding the table's column count
- If the diff contains TODO comments, list the file path and TODO text in the 備考 section. If there are none, omit that section
- Do not include TODO lists, test checklists, or review-point sections
