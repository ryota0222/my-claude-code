#!/usr/bin/env bash
# scan.sh - Read-only aggregation of cleanup candidates under ~/.claude/
# Outputs JSON to stdout.
set -eu

BASE_DIR="$HOME/.claude"

while [ $# -gt 0 ]; do
  case "$1" in
    --base-dir) BASE_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ ! -d "$BASE_DIR" ]; then
  echo "Base dir not found: $BASE_DIR" >&2
  exit 1
fi

# ---------- Tier A: cleanupPeriodDays ----------
CLEANUP_SET="false"
if [ -f "$BASE_DIR/settings.json" ]; then
  if jq -e '.cleanupPeriodDays // empty' "$BASE_DIR/settings.json" >/dev/null 2>&1; then
    CLEANUP_SET="true"
  fi
fi

# ---------- Tier B: empty todos (2-byte "[]") ----------
EMPTY_TODOS_LIST="[]"
EMPTY_TODOS_COUNT=0
if [ -d "$BASE_DIR/todos" ]; then
  EMPTY_TODOS_LIST=$(find "$BASE_DIR/todos" -maxdepth 1 -type f -name "*.json" -size 2c | jq -R . | jq -s .)
  EMPTY_TODOS_COUNT=$(echo "$EMPTY_TODOS_LIST" | jq 'length')
fi

# ---------- Tier C: old shell-snapshots / debug ----------
OLD_SNAPS_LIST="[]"
OLD_SNAPS_COUNT=0
if [ -d "$BASE_DIR/shell-snapshots" ]; then
  OLD_SNAPS_LIST=$(find "$BASE_DIR/shell-snapshots" -maxdepth 1 -type f -name "*.sh" -mtime +7 | jq -R . | jq -s .)
  OLD_SNAPS_COUNT=$(echo "$OLD_SNAPS_LIST" | jq 'length')
fi

OLD_DEBUG_LIST="[]"
OLD_DEBUG_COUNT=0
if [ -d "$BASE_DIR/debug" ]; then
  LATEST_TARGET=""
  if [ -L "$BASE_DIR/debug/latest" ]; then
    LATEST_TARGET=$(readlink "$BASE_DIR/debug/latest")
    LATEST_TARGET=$(basename "$LATEST_TARGET")
  fi
  OLD_DEBUG_LIST=$(find "$BASE_DIR/debug" -maxdepth 1 -type f -name "*.txt" -mtime +7 | jq -R . | jq -s --arg exclude "$LATEST_TARGET" 'map(select((. | split("/") | last) != $exclude))')
  OLD_DEBUG_COUNT=$(echo "$OLD_DEBUG_LIST" | jq 'length')
fi

# ---------- Active sessions (PID alive) ----------
ACTIVE_SESSIONS="[]"
if [ -d "$BASE_DIR/sessions" ]; then
  TMP_IDS=""
  shopt -s nullglob
  for f in "$BASE_DIR"/sessions/*.json; do
    [ -f "$f" ] || continue
    PID=$(jq -r '.pid // empty' "$f" 2>/dev/null || echo "")
    SID=$(jq -r '.sessionId // empty' "$f" 2>/dev/null || echo "")
    if [ -n "$PID" ] && [ -n "$SID" ] && ps -p "$PID" > /dev/null 2>&1; then
      TMP_IDS="$TMP_IDS$SID"$'\n'
    fi
  done
  shopt -u nullglob
  ACTIVE_SESSIONS=$(printf "%s" "$TMP_IDS" | jq -R . | jq -s 'map(select(. != ""))')
fi

# ---------- Tier D: session-env orphans ----------
ORPHAN_SENV_LIST="[]"
ORPHAN_SENV_COUNT=0
if [ -d "$BASE_DIR/session-env" ]; then
  ORPHAN_SENV_LIST=$(find "$BASE_DIR/session-env" -mindepth 1 -maxdepth 1 -type d | jq -R . | jq -s \
    --argjson active "$ACTIVE_SESSIONS" \
    'map(select((. | split("/") | last) as $uuid | ($active | index($uuid) | not)))')
  ORPHAN_SENV_COUNT=$(echo "$ORPHAN_SENV_LIST" | jq 'length')
fi

# ---------- Tier D: file-history orphans ----------
ORPHAN_FH_LIST="[]"
ORPHAN_FH_COUNT=0
if [ -d "$BASE_DIR/file-history" ]; then
  PROJECT_UUIDS=$(find "$BASE_DIR/projects" -maxdepth 3 -type f -name "*.jsonl" 2>/dev/null \
    | sed 's/.*\///; s/\.jsonl$//' | jq -R . | jq -s .)
  ORPHAN_FH_LIST=$(find "$BASE_DIR/file-history" -mindepth 1 -maxdepth 1 -type d | jq -R . | jq -s \
    --argjson projects "$PROJECT_UUIDS" \
    'map(select((. | split("/") | last) as $uuid | ($projects | index($uuid) | not)))')
  ORPHAN_FH_COUNT=$(echo "$ORPHAN_FH_LIST" | jq 'length')
fi

# ---------- Tier D: tasks (all) ----------
ALL_TASKS_LIST="[]"
ALL_TASKS_COUNT=0
if [ -d "$BASE_DIR/tasks" ]; then
  ALL_TASKS_LIST=$(find "$BASE_DIR/tasks" -mindepth 1 -maxdepth 1 -type d | jq -R . | jq -s .)
  ALL_TASKS_COUNT=$(echo "$ALL_TASKS_LIST" | jq 'length')
fi

# ---------- Tier D: history.jsonl lines older than 6 months ----------
HISTORY_OLD_LINES=0
if [ -f "$BASE_DIR/history.jsonl" ]; then
  CUTOFF_MS=$(( $(date -v-6m +%s) * 1000 ))
  HISTORY_OLD_LINES=$(jq -s --argjson cutoff "$CUTOFF_MS" '[.[] | select(.timestamp < $cutoff)] | length' "$BASE_DIR/history.jsonl" 2>/dev/null || echo 0)
  [ -z "$HISTORY_OLD_LINES" ] && HISTORY_OLD_LINES=0
  [[ "$HISTORY_OLD_LINES" =~ ^[0-9]+$ ]] || HISTORY_OLD_LINES=0
fi

# ---------- totalBytes ----------
sum_sizes() {
  local list="$1"
  local total=0 sz kb
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if [ -d "$p" ]; then
      kb=$(du -sk "$p" 2>/dev/null | awk '{print $1}')
      sz=$(( ${kb:-0} * 1024 ))
    elif [ -f "$p" ]; then
      sz=$(stat -f %z "$p" 2>/dev/null || echo 0)
    else
      sz=0
    fi
    [ -z "$sz" ] && sz=0
    total=$((total + sz))
  done < <(echo "$list" | jq -r '.[]')
  echo "$total"
}

BYTES_ABC=0
BYTES_ABC=$(( BYTES_ABC + $(sum_sizes "$EMPTY_TODOS_LIST") ))
BYTES_ABC=$(( BYTES_ABC + $(sum_sizes "$OLD_SNAPS_LIST") ))
BYTES_ABC=$(( BYTES_ABC + $(sum_sizes "$OLD_DEBUG_LIST") ))

BYTES_D=0
BYTES_D=$(( BYTES_D + $(sum_sizes "$ORPHAN_SENV_LIST") ))
BYTES_D=$(( BYTES_D + $(sum_sizes "$ORPHAN_FH_LIST") ))
BYTES_D=$(( BYTES_D + $(sum_sizes "$ALL_TASKS_LIST") ))
if [ -f "$BASE_DIR/history.jsonl" ] && [ "$HISTORY_OLD_LINES" -gt 0 ]; then
  TOTAL_LINES=$(wc -l < "$BASE_DIR/history.jsonl" | tr -d ' ')
  TOTAL_BYTES=$(stat -f %z "$BASE_DIR/history.jsonl")
  if [ "$TOTAL_LINES" -gt 0 ]; then
    BYTES_D=$(( BYTES_D + TOTAL_BYTES * HISTORY_OLD_LINES / TOTAL_LINES ))
  fi
fi

# ---------- Emit JSON ----------
jq -n \
  --arg cleanup "$CLEANUP_SET" \
  --argjson emptyTodos "$EMPTY_TODOS_COUNT" \
  --argjson emptyTodosList "$EMPTY_TODOS_LIST" \
  --argjson oldSnaps "$OLD_SNAPS_COUNT" \
  --argjson oldSnapsList "$OLD_SNAPS_LIST" \
  --argjson oldDebug "$OLD_DEBUG_COUNT" \
  --argjson oldDebugList "$OLD_DEBUG_LIST" \
  --argjson orphanSenv "$ORPHAN_SENV_COUNT" \
  --argjson orphanSenvList "$ORPHAN_SENV_LIST" \
  --argjson orphanFh "$ORPHAN_FH_COUNT" \
  --argjson orphanFhList "$ORPHAN_FH_LIST" \
  --argjson allTasks "$ALL_TASKS_COUNT" \
  --argjson allTasksList "$ALL_TASKS_LIST" \
  --argjson historyOld "$HISTORY_OLD_LINES" \
  --argjson bytesABC "$BYTES_ABC" \
  --argjson bytesD "$BYTES_D" \
  --argjson active "$ACTIVE_SESSIONS" \
  '{
    tierA: {cleanupPeriodDaysSet: ($cleanup == "true")},
    tierB: {emptyTodos: $emptyTodos, emptyTodosList: $emptyTodosList},
    tierC: {
      oldShellSnapshots: $oldSnaps, oldShellSnapshotsList: $oldSnapsList,
      oldDebugTxt: $oldDebug, oldDebugTxtList: $oldDebugList
    },
    tierD: {
      orphanSessionEnv: $orphanSenv, orphanSessionEnvList: $orphanSenvList,
      orphanFileHistory: $orphanFh, orphanFileHistoryList: $orphanFhList,
      allTasks: $allTasks, allTasksList: $allTasksList,
      historyJsonlOldLines: $historyOld
    },
    totalBytes: {tierABC: $bytesABC, tierD: $bytesD},
    activeSessionIds: $active
  }'
