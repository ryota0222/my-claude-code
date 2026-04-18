---
name: commit
description: Create Conventional Commits messages written in Japanese. Use when making a commit, when `/commit` is invoked, or when the user asks for a commit message. Analyzes `git diff` and generates an appropriate type, scope, and description in Japanese.
---

# Conventional Commits (Japanese output)

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

## Types

| Type | Use |
| --- | --- |
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation-only changes |
| `style` | Non-semantic changes (whitespace, formatting, etc.) |
| `refactor` | Code change that is neither a fix nor a feature |
| `perf` | Performance improvement |
| `test` | Add or fix tests |
| `build` | Build system or external dependency changes |
| `ci` | CI config/script changes |
| `chore` | Other chores (version bumps, etc.) |

## Procedure

**Always run `git diff --staged --stat` and `git status` first**, then follow the flow below.

### Step 1: Check staged files

- Staged files **exist** → go to Step 2a
- Staged files **do not exist** → go to Step 2b

### Step 2a: Commit staged files (regardless of arguments)

1. Run `git diff --staged` to inspect staged changes
2. Plan the commit using **only those files** (do not stage more)
3. Present the **commit plan** to the user for approval:
   - List of files to commit
   - Proposed commit message
4. Run `git commit` once approved

### Step 2b: Analyze unstaged changes and propose splits

1. Inspect unstaged changes with `git status` and `git diff`
2. If an argument is given (`/commit <topic>`), narrow to files related to it
3. Analyze and propose a **commit split plan** at an appropriate granularity:
   - Files per commit
   - Proposed message per commit
   - Rationale for the split (feature unit, fix unit, etc.)
4. Once approved (or revised), run `git add <files>` → `git commit` in the approved order
5. Execute multiple commits one at a time, in order

## Common Rules

- Write in **Japanese**
- `scope` is optional; include it when it helps clarity
  - In multi-language repos, include the language (`kotlin`, `typescript`, etc.)
- No period (`。`) at the end of `description` (length-limited)
- `description` may use present tense, past tense, or noun-ending form
- `body` has no length limit; use proper Japanese punctuation and grammar

## Rules per Type

### feat (feature add / change / remove)

- `description` states what feature was added/changed/removed
- `body` is optional; include background when it clarifies intent

```
feat(kotlin): トークンを取得するエンドポイントを追加
```

```
feat(kotlin): リクエストのフィールドにタイムゾーンを追加

タイムゾーンを含めて発着時刻を計算する必要があるため。
```

### fix (bug fix)

- `description` states what bug was fixed
- `body` is **required**; state the root cause

```
fix(kotlin): 外部APIへのリクエストが失敗するバグを修正

必要なリクエストパラメーターが設定されていなかった。
```

### refactor (refactoring)

- Changes to internal structure without changing interface/endpoint behavior
- For IaC, changes that do not alter infrastructure configuration
- `description` states how it was changed
- `body` is **generally required**; state the motivation
  - May be omitted if the motivation is already in `description`

```
refactor(kotlin): メソッド名を変更

処理の内容を正しく表現できていなかったため。
```

```
refactor(kotlin): 未使用変数を削除
```

### Other type examples

```
docs: CLAUDE.mdを更新した
chore: アプリバージョンを変更した
test: useAppIconのユニットテストを追加
```
