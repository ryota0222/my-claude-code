---
name: clean-claude-code
description: Use when running `/clean-claude-code`, or when the user asks to clean up `~/.claude/`. Interactively delete unused files under `~/.claude/`. Proposes Tier A-C (empty todos, old shell-snapshots/debug, missing cleanupPeriodDays) by default, and runs Tier D (undocumented areas: session-env / file-history / tasks / history.jsonl) only with an additional opt-in confirmation. Files belonging to the current session are always protected via live-PID detection against `sessions/*.json`.
---

# /clean-claude-code

User-scope skill that interactively cleans up unused files under `~/.claude/`.

## Invocation

- When the user types `/clean-claude-code`
- Or when the user explicitly asks this skill to run

## Operating principles (for Claude)

1. **Run scan.sh only once** and cache the JSON to `/tmp/clean-claude-code-scan.$$.json`. Subsequent steps query this cache with `jq` instead of re-scanning. (Exception: a single freshness re-check right before Tier D deletions.)
2. Deletion commands must use the `-exec rm {}` form. `find ... -delete` is denied by `~/.claude/settings.json`.
3. All user-facing messages are in Japanese (templates below).
4. Log every deletion before and after, and print a completion report at the end.
5. Never skip a y/n prompt — always show it to the user and wait for their input.

---

## Step 1: Run scan.sh and cache

Run the following block exactly once to cache the JSON output.

```bash
trap 'rm -f /tmp/clean-claude-code-*.$$.*' EXIT

# Reclaim stale /tmp files left by prior runs that died abnormally (e.g., SIGKILL).
# Extract the PID embedded in the filename (.<PID>.<ext>) and delete only if the PID is dead.
# Tmp files owned by other live sessions are left untouched.
for f in /tmp/clean-claude-code-*.*; do
  [ -e "$f" ] || continue
  pid=$(basename "$f" | sed -E 's/^clean-claude-code-.*\.([0-9]+)\.[^.]+$/\1/')
  if [[ "$pid" =~ ^[0-9]+$ ]] && ! ps -p "$pid" > /dev/null 2>&1; then
    rm -- "$f" 2>/dev/null
  fi
done

SCAN="/tmp/clean-claude-code-scan.$$.json"
bash ~/.claude/skills/clean-claude-code/scan.sh > "$SCAN"
jq . "$SCAN" >/dev/null || { echo "scan.sh produced invalid JSON; aborting." >&2; exit 1; }
```

If this block fails, abort here and tell the user: 「scan.sh が失敗したため中止しました」.

Later steps treat `$SCAN` (= `/tmp/clean-claude-code-scan.$$.json`) as a read-only input. The `$$` in the filename keeps parallel invocations from colliding.

---

## Step 2: Present the summary to the user

Read the cached JSON and render the Japanese summary below.

Example `jq` extraction:

```bash
SCAN="/tmp/clean-claude-code-scan.$$.json"
CLEANUP_SET=$(jq -r '.tierA.cleanupPeriodDaysSet' "$SCAN")
EMPTY_TODOS=$(jq -r '.tierB.emptyTodos' "$SCAN")
OLD_SNAPS=$(jq -r '.tierC.oldShellSnapshots' "$SCAN")
OLD_DEBUG=$(jq -r '.tierC.oldDebugTxt' "$SCAN")
BYTES_ABC=$(jq -r '.totalBytes.tierABC' "$SCAN")
ACTIVE_N=$(jq -r '.activeSessionIds | length' "$SCAN")
MB_ABC=$(awk -v b="$BYTES_ABC" 'BEGIN{printf "%.2f", b/1024/1024}')
```

Display template (substitute the variables above):

```
clean-claude-code scan 結果

Tier A: cleanupPeriodDays { 未設定 / 設定済み }
Tier B: 空 todos ファイル {EMPTY_TODOS} 個
Tier C: 古い shell-snapshots {OLD_SNAPS} 個、古い debug {OLD_DEBUG} 個
        （7 日以上前のファイル）

小計（Tier A + B + C）: 約 {MB_ABC} MB

現在 {ACTIVE_N} セッション稼働中、これらは保護されます。

続行しますか？ (y/n)
```

- If `CLEANUP_SET` is `false`, append an additional question:
  ```
  さらに ~/.claude/settings.json に "cleanupPeriodDays": 30 を追加提案しますか？ (y/n)
  ```
  The answer feeds into Step 3's Tier A block.

### Branching

- If the user answers `n` to the main prompt: abort without writing a log, and say 「中止しました。何も削除していません。」. Do not continue to Step 3.
- Proceed to Step 3 only on `y`.

---

## Step 3: Execute Tier A+B+C

Run the following blocks in order only if the user answered `y` to Step 2's main question.

### 3.1 Initialize the log file

```bash
SCAN="/tmp/clean-claude-code-scan.$$.json"
mkdir -p ~/.claude/skills/clean-claude-code/logs
LOG=~/.claude/skills/clean-claude-code/logs/clean-$(date +%Y-%m-%d-%H%M%S).log
{
  echo "[$(date '+%F %T')] /clean-claude-code started"
  echo "[scan] $(jq -c . "$SCAN")"
  echo "[active] sessionIds: $(jq -r '.activeSessionIds | join(", ")' "$SCAN")"
} > "$LOG"
```

Subsequent blocks assume `$LOG` and `$SCAN` are valid. Either run them in the same bash session, or redefine them at the top of each block.

### 3.2 Tier A: add cleanupPeriodDays (only with user consent)

Only run this block if the user answered `y` to the Step 2 follow-up question AND `CLEANUP_SET=false`.

```bash
if [ "$(jq -r '.tierA.cleanupPeriodDaysSet' "$SCAN")" = "false" ]; then
  jq '. + {cleanupPeriodDays: 30}' ~/.claude/settings.json > "/tmp/clean-claude-code-settings.$$.tmp" \
    && mv "/tmp/clean-claude-code-settings.$$.tmp" ~/.claude/settings.json \
    && echo "[$(date '+%F %T')] [Tier A] settings.json updated: cleanupPeriodDays=30" >> "$LOG"
fi
```

Skip this block entirely if the user answered `n` to the follow-up question.

### 3.3 Tier B: delete empty todos

```bash
jq -r '.tierB.emptyTodosList[]' "$SCAN" | while IFS= read -r p; do
  [ -z "$p" ] && continue
  [ -e "$p" ] || continue
  size=$(stat -f %z "$p" 2>/dev/null || echo 0)
  if rm -- "$p" 2>/dev/null; then
    echo "[$(date '+%F %T')] [Tier B] deleted: $p ($size bytes)" >> "$LOG"
  else
    echo "[$(date '+%F %T')] [Tier B] FAILED: $p" >> "$LOG"
  fi
done
```

### 3.4 Tier C: delete old shell-snapshots

```bash
jq -r '.tierC.oldShellSnapshotsList[]' "$SCAN" | while IFS= read -r p; do
  [ -z "$p" ] && continue
  [ -e "$p" ] || continue
  size=$(stat -f %z "$p" 2>/dev/null || echo 0)
  if rm -- "$p" 2>/dev/null; then
    echo "[$(date '+%F %T')] [Tier C] deleted: $p ($size bytes)" >> "$LOG"
  else
    echo "[$(date '+%F %T')] [Tier C] FAILED: $p" >> "$LOG"
  fi
done
```

### 3.5 Tier C: delete old debug files

```bash
jq -r '.tierC.oldDebugTxtList[]' "$SCAN" | while IFS= read -r p; do
  [ -z "$p" ] && continue
  [ -e "$p" ] || continue
  size=$(stat -f %z "$p" 2>/dev/null || echo 0)
  if rm -- "$p" 2>/dev/null; then
    echo "[$(date '+%F %T')] [Tier C] deleted: $p ($size bytes)" >> "$LOG"
  else
    echo "[$(date '+%F %T')] [Tier C] FAILED: $p" >> "$LOG"
  fi
done
```

Proceed to Step 4 once all three blocks complete.

---

## Step 4: Confirm Tier D (opt-in)

Read the Tier D counts from the cache:

```bash
SCAN="/tmp/clean-claude-code-scan.$$.json"
ORPH_SENV=$(jq -r '.tierD.orphanSessionEnv' "$SCAN")
ORPH_FH=$(jq -r '.tierD.orphanFileHistory' "$SCAN")
ALL_TASKS=$(jq -r '.tierD.allTasks' "$SCAN")
HIST_OLD=$(jq -r '.tierD.historyJsonlOldLines' "$SCAN")
ACTIVE_N=$(jq -r '.activeSessionIds | length' "$SCAN")
```

If `ORPH_SENV + ORPH_FH + ALL_TASKS + HIST_OLD` is zero, **skip the Tier D prompt entirely** and go to Step 5.

If any of them is non-zero, show the following confirmation and wait for the user:

```
Tier D（実験的・非公式領域）も含めますか？

⚠️ Claude Code の公式仕様に記載されていない内部ディレクトリに触れます。
   将来のバージョンアップで挙動が変わる可能性があります。

対象:
 - session-env 孤児 {ORPH_SENV} 個
 - file-history 孤児 {ORPH_FH} 個
 - tasks ディレクトリ {ALL_TASKS} 個
 - history.jsonl 6 ヶ月より古い行 {HIST_OLD} 行を切り詰め

現行セッション ({ACTIVE_N} 個) は保護されます。

続行しますか？ (y/n)
```

If `n`, jump straight to Step 5. Proceed below only on `y`.

### 4.0 TOCTOU guard: freshness re-check before Tier D deletions

Right after the user answers `y`, re-run scan.sh **once more** to avoid operating on a stale cache (another session may have claimed files in the meantime). Delete only paths present in **both** snapshots — the intersection.

```bash
RECHECK="/tmp/clean-claude-code-scan-recheck.$$.json"
bash ~/.claude/skills/clean-claude-code/scan.sh > "$RECHECK"
jq . "$RECHECK" >/dev/null || { echo "scan.sh re-check produced invalid JSON; aborting Tier D." >&2; exit 1; }

# Keep only paths present in both snapshots (intersection).
SAFE_SESSION_ENV=$(jq -n \
  --slurpfile a <(jq '.tierD.orphanSessionEnvList' "$SCAN") \
  --slurpfile b <(jq '.tierD.orphanSessionEnvList' "$RECHECK") \
  '$a[0] - ($a[0] - $b[0])')
SAFE_FILE_HISTORY=$(jq -n \
  --slurpfile a <(jq '.tierD.orphanFileHistoryList' "$SCAN") \
  --slurpfile b <(jq '.tierD.orphanFileHistoryList' "$RECHECK") \
  '$a[0] - ($a[0] - $b[0])')
SAFE_TASKS=$(jq -n \
  --slurpfile a <(jq '.tierD.allTasksList' "$SCAN") \
  --slurpfile b <(jq '.tierD.allTasksList' "$RECHECK") \
  '$a[0] - ($a[0] - $b[0])')
```

Use the `$SAFE_*` variables as the iteration source in 4.1-4.3. The `history.jsonl` truncation in 4.4 operates on a single file and is idempotent, so no re-check is needed there.

### 4.1 Delete orphan session-env directories

```bash
printf '%s\n' "$SAFE_SESSION_ENV" | jq -r '.[]' | while IFS= read -r d; do
  [ -z "$d" ] && continue
  [ -d "$d" ] || continue
  size=$(du -sk "$d" 2>/dev/null | awk '{print $1*1024}')
  find "$d" -type f -exec rm -- {} + 2>/dev/null
  find "$d" -depth -type d -exec rmdir -- {} + 2>/dev/null
  if [ ! -e "$d" ]; then
    echo "[$(date '+%F %T')] [Tier D] rmdir session-env: $d (${size:-0} bytes)" >> "$LOG"
  else
    echo "[$(date '+%F %T')] [Tier D] FAILED session-env: $d" >> "$LOG"
  fi
done
```

### 4.2 Delete orphan file-history directories

```bash
printf '%s\n' "$SAFE_FILE_HISTORY" | jq -r '.[]' | while IFS= read -r d; do
  [ -z "$d" ] && continue
  [ -d "$d" ] || continue
  size=$(du -sk "$d" 2>/dev/null | awk '{print $1*1024}')
  find "$d" -type f -exec rm -- {} + 2>/dev/null
  find "$d" -depth -type d -exec rmdir -- {} + 2>/dev/null
  if [ ! -e "$d" ]; then
    echo "[$(date '+%F %T')] [Tier D] rmdir file-history: $d (${size:-0} bytes)" >> "$LOG"
  else
    echo "[$(date '+%F %T')] [Tier D] FAILED file-history: $d" >> "$LOG"
  fi
done
```

### 4.3 Delete all tasks directories

```bash
printf '%s\n' "$SAFE_TASKS" | jq -r '.[]' | while IFS= read -r d; do
  [ -z "$d" ] && continue
  [ -d "$d" ] || continue
  size=$(du -sk "$d" 2>/dev/null | awk '{print $1*1024}')
  find "$d" -type f -exec rm -- {} + 2>/dev/null
  find "$d" -depth -type d -exec rmdir -- {} + 2>/dev/null
  if [ ! -e "$d" ]; then
    echo "[$(date '+%F %T')] [Tier D] rmdir tasks: $d (${size:-0} bytes)" >> "$LOG"
  else
    echo "[$(date '+%F %T')] [Tier D] FAILED tasks: $d" >> "$LOG"
  fi
done
```

### 4.4 Truncate history.jsonl at the 6-month cutoff

Run this block only if `HIST_OLD > 0` AND the file exists.

- `select(.timestamp == null or .timestamp >= $cutoff)` also preserves lines missing `.timestamp` — without the explicit null case, jq treats null as false and would silently drop such rows.
- If the filter emits zero lines, `mv`-ing would wipe the file entirely, so check the line count first.

```bash
if [ -f ~/.claude/history.jsonl ] && [ "$(jq -r '.tierD.historyJsonlOldLines' "$SCAN")" -gt 0 ]; then
  CUTOFF_MS=$(( $(date -v-6m +%s) * 1000 ))
  BEFORE=$(wc -l < ~/.claude/history.jsonl | tr -d ' ')
  BEFORE_BYTES=$(stat -f %z ~/.claude/history.jsonl 2>/dev/null || echo 0)
  NEWFILE="/tmp/clean-claude-code-history.$$.new"
  jq -c --argjson cutoff "$CUTOFF_MS" 'select(.timestamp == null or .timestamp >= $cutoff)' \
    ~/.claude/history.jsonl > "$NEWFILE"
  AFTER=$(wc -l < "$NEWFILE" | tr -d ' ')
  if [ "$AFTER" -gt 0 ]; then
    mv "$NEWFILE" ~/.claude/history.jsonl
    AFTER_BYTES=$(stat -f %z ~/.claude/history.jsonl 2>/dev/null || echo 0)
    SAVED=$(( BEFORE_BYTES - AFTER_BYTES ))
    echo "[$(date '+%F %T')] [Tier D] truncated history.jsonl (${BEFORE} -> ${AFTER} lines, ${SAVED} bytes saved)" >> "$LOG"
  else
    echo "[$(date '+%F %T')] [Tier D] SKIPPED: history.jsonl truncation would yield empty file" >> "$LOG"
    rm -f "$NEWFILE"
  fi
fi
```

Proceed to Step 5.

---

## Step 5: Final report

Aggregate the deletion count and freed bytes from the log file, then show the result to the user in Japanese.

```bash
LOG_FILE="$LOG"  # Log path set in Step 3
DELETED_COUNT=$(grep -cE '\[Tier [A-D]\] (deleted|rmdir|truncated)' "$LOG_FILE" || true)
# Sum bytes from deleted/rmdir lines — "(<N> bytes)" inside parentheses.
SAVED_BYTES=$(grep -oE '\(([0-9]+) bytes\)' "$LOG_FILE" | grep -oE '[0-9]+' | awk '{s+=$1} END{print s+0}')
# Add history.jsonl saved bytes as well.
HIST_SAVED=$(grep -oE '([0-9]+) bytes saved' "$LOG_FILE" | grep -oE '[0-9]+' | awk '{s+=$1} END{print s+0}')
TOTAL_SAVED=$(( SAVED_BYTES + HIST_SAVED ))
SAVED_MB=$(awk -v b="$TOTAL_SAVED" 'BEGIN{printf "%.2f", b/1024/1024}')
CLEANUP_NOW=$(jq -r '.cleanupPeriodDays // "未設定"' ~/.claude/settings.json 2>/dev/null || echo "未設定")

echo "[$(date '+%F %T')] completed" >> "$LOG_FILE"

cat <<EOF
clean-claude-code 完了

削除: ${DELETED_COUNT} 件 / 約 ${SAVED_MB} MB 解放
ログ: ${LOG_FILE}

次回の自動クリーンアップ:
 - cleanupPeriodDays: ${CLEANUP_NOW} 日（起動時に projects/ を自動整理）
EOF
```

`/clean-claude-code` is complete.

---

## Notes (for Claude)

- **Do not re-scan**: re-running scan.sh after Step 3/4 deletions would produce a stale cache for the Step 5 report. Aggregate the report from the **log file** (as in the template above).
- **Do not skip y/n prompts**: the main prompt in Step 2, the Tier A follow-up, and the Tier D confirmation in Step 4 must all be shown to the user with an explicit answer awaited.
- **Active session protection**: scan.sh's `*List` fields are already filtered to exclude `activeSessionIds`, so SKILL.md needs no additional exclusion logic.
- **Fault tolerance**: if an individual file deletion fails, log a `FAILED` line and continue.
- **Environment**: macOS (Darwin), zsh or bash, jq 1.7. `date -v-6m` is BSD date syntax.
