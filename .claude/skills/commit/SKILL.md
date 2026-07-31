---
name: commit
description: Creates Japanese commit messages that follow the Conventional Commits specification. Use when creating a commit, when `/commit` is run, or when the user asks for a commit message ("コミットメッセージ"). Analyzes the git diff and generates an appropriate type, scope, and Japanese description.
---

# Conventional Commits (Japanese output)

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

## Type

| Type | Purpose |
| --- | --- |
| `feat` | Adding a new feature |
| `fix` | Fixing a bug |
| `docs` | Documentation-only changes |
| `style` | Changes that do not affect the meaning of the code (whitespace, formatting, etc.) |
| `refactor` | A code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `build` | Changes to the build system or external dependencies |
| `ci` | Changes to CI configuration files or scripts |
| `chore` | Other chores that fit none of the above (version bumps, etc.) |

## Procedure

**Always run `git diff --staged --stat` and `git status` first**, then follow this flow.

### Step 1: Check for staged files

- Staged files **exist** → go to Step 2a
- Staged files **do not exist** → go to Step 2b

### Step 2a: Commit the staged files (whether or not an argument was given)

1. Review the staged changes with `git diff --staged`
2. Plan the commit against **those files only** (do not stage anything else)
3. Present the **commit plan** to the user and ask for approval:
   - The list of files to be committed
   - The proposed commit message
4. Run `git commit` once the user approves

### Step 2b: Analyze unstaged changes and propose a split

1. Explore the unstaged changes with `git status` and `git diff`
2. When an argument is given (`/commit <description>`), narrow down to the files related to that argument
3. Analyze the changes and present a **proposal that splits them into appropriately sized commits**:
   - The list of files for each commit
   - The proposed message for each commit
   - The rationale for the split (per feature, per fix, etc.)
4. Once the user approves (or asks for revisions), run `git add <files>` → `git commit` in the approved order
5. When there are multiple commits, run them one at a time in order

## Common Rules

- Write in **Japanese**
- `scope` is not required. Include it when it makes the commit easier to understand
  - In a multi-language repository, name the language that was changed (`kotlin`, `typescript`, etc.)
- Do not end `description` with a period, because it has a length limit
- The verb in `description` may be present tense, past tense, or noun form (体言止め)
- Write `body` as grammatically correct Japanese prose with appropriate punctuation

## Rules per Type

### feat (adding, changing, or removing a feature)

- `description` states which feature was added, changed, or removed
- `body` is optional. Include it when describing the background makes the intent easier to understand

```
feat(kotlin): トークンを取得するエンドポイントを追加
```

```
feat(kotlin): リクエストのフィールドにタイムゾーンを追加

タイムゾーンを含めて発着時刻を計算する必要があるため。
```

### fix (bug fix)

- `description` states which bug was fixed
- `body` is **required**. State why the bug occurred

```
fix(kotlin): 外部APIへのリクエストが失敗するバグを修正

必要なリクエストパラメーターが設定されていなかった。
```

### refactor (refactoring)

- A change that reorganizes internal structure without altering the behavior of interfaces or endpoints
- For IaC, this covers changes that do not alter the infrastructure configuration
- `description` states how the code was changed
- `body` is **required in principle**. State the motivation for the change
  - It may be omitted when `description` already conveys the motivation

```
refactor(kotlin): メソッド名を変更

処理の内容を正しく表現できていなかったため。
```

```
refactor(kotlin): 未使用変数を削除
```

### Examples of other types

```
docs: CLAUDE.mdを更新した
chore: アプリバージョンを変更した
test: useAppIconのユニットテストを追加
```
