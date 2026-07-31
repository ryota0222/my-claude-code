---
name: create-pr-description
description: Use when running `/create-pr-description`, or when the user asks to write a PR description. Analyzes branch commits and generates a Japanese PR title and description with appropriate sections based on FE/BE detection. Does NOT create the PR - only proposes the content.
---

# PR Description Skill

Proposes a Japanese PR title and description from the commits on the current branch. Does not create the PR.

## Procedure

### Step 1: Collect branch information

Run the following in parallel:

```bash
# All commits since the base branch
git log main..HEAD --oneline

# Overall shape of the changes
git diff main...HEAD --stat

# Current branch name
git branch --show-current

# Remote state
git status

# TODO comments inside the diff
git diff main...HEAD | grep -n "^+.*TODO"
```

### Step 2: Detect FE/BE

Judge holistically from the file extensions, paths, and project layout of the changed files:

| Signal | Verdict |
| --- | --- |
| `.tsx`, `.jsx`, `.vue`, `.svelte`, `next.config`, `nuxt.config`, `vite.config`, `src/components/`, `src/pages/`, `public/` | **FE** |
| `.go`, `.py`, `.rb`, `.java`, `.rs`, `internal/`, `cmd/`, `api/`, `server/`, `migrations/`, `Dockerfile` | **BE** |
| `package.json`, `.ts`, `.js` | **Decide from context** (FE for UI components, BE for server-side) |
| Both are present | **FE+BE** |

When the verdict is unclear, check the technology stack from the repository README or the dependencies in `package.json`.

### Step 3: Generate the PR description

Generate it in the following format. Analyze the commits and summarize the **purpose and outline of the change** concisely.

#### Format for FE:

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

#### Format for BE:

```markdown
## 概要
<!-- 変更の目的と概要を1-3行で記述 -->

## 変更内容
<!-- 主な変更点を箇条書きで記述 -->

## 備考（※TODOコメントがある場合のみ）
- `ファイルパス`: TODOコメントの内容
```

### Step 4: Present the proposal

Present the PR title and description to the user. Do not create the PR (`gh pr create` or push).

## Rules

- Keep the PR title within 70 characters and write it concisely in Japanese
- Do not simply list the commit messages. Summarize the **purpose** of the change
- The 概要 section states why the change is needed
- The 変更内容 section lists the technical changes as bullet points
- Always include the 画面キャプチャ section for an FE verdict. Confirm the number of table columns (how many screens to attach) with the user before deciding
- When the diff contains TODO comments, record the file path and TODO content in the 備考 section. Omit the 備考 section when there is no TODO
- Do not include TODO lists, test checklists, or review points
