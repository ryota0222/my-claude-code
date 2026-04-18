#!/usr/bin/env bash
# Unit tests for scan.sh
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  OK $msg"
  else
    echo "  FAIL $msg (expected: $expected, got: $actual)"
    return 1
  fi
}

# ---------- Test: minimal fixture -> all-zero JSON ----------
OUT=$(bash "$SKILL_DIR/scan.sh" --base-dir "$SCRIPT_DIR/fixtures/minimal")
assert_eq "$(echo "$OUT" | jq -r .tierA.cleanupPeriodDaysSet)" "false" "minimal: tierA.cleanupPeriodDaysSet=false" || exit 1
assert_eq "$(echo "$OUT" | jq -r .tierB.emptyTodos)" "0" "minimal: tierB.emptyTodos=0" || exit 1
assert_eq "$(echo "$OUT" | jq -r .tierC.oldShellSnapshots)" "0" "minimal: tierC.oldShellSnapshots=0" || exit 1

# ---------- Test: Tier A cleanupPeriodDays set ----------
OUT=$(bash "$SKILL_DIR/scan.sh" --base-dir "$SCRIPT_DIR/fixtures/tierA_set")
assert_eq "$(echo "$OUT" | jq -r .tierA.cleanupPeriodDaysSet)" "true" "tierA: cleanupPeriodDays=true" || exit 1

# ---------- Test: Tier B empty todos ----------
OUT=$(bash "$SKILL_DIR/scan.sh" --base-dir "$SCRIPT_DIR/fixtures/tierB")
assert_eq "$(echo "$OUT" | jq -r .tierB.emptyTodos)" "3" "tierB: emptyTodos=3" || exit 1
assert_eq "$(echo "$OUT" | jq -r '.tierB.emptyTodosList | length')" "3" "tierB: list length=3" || exit 1

# ---------- Test: Tier C old shell-snapshots & debug ----------
OUT=$(bash "$SKILL_DIR/scan.sh" --base-dir "$SCRIPT_DIR/fixtures/tierC")
assert_eq "$(echo "$OUT" | jq -r .tierC.oldShellSnapshots)" "2" "tierC: oldShellSnapshots=2" || exit 1
assert_eq "$(echo "$OUT" | jq -r .tierC.oldDebugTxt)" "2" "tierC: oldDebugTxt=2 (latest excluded)" || exit 1

# ---------- Dynamic fixture: active_sessions (uses $$) ----------
setup_active_fixture() {
  # $$ = test runner PID, guaranteed alive during scan.sh child process.
  local fix="$SCRIPT_DIR/fixtures/active_sessions_dyn"
  rm -rf "$fix"
  mkdir -p "$fix"/{todos,shell-snapshots,debug,session-env,file-history,tasks,projects,sessions}
  echo '{}' > "$fix/settings.json"
  touch "$fix/history.jsonl"
  cat > "$fix/sessions/$$.json" <<EOF
{"pid":$$,"sessionId":"live-session-uuid","cwd":"/tmp","startedAt":0,"kind":"interactive","entrypoint":"test"}
EOF
  cat > "$fix/sessions/999999.json" <<EOF
{"pid":999999,"sessionId":"dead-session-uuid","cwd":"/tmp","startedAt":0,"kind":"interactive","entrypoint":"test"}
EOF
  echo "$fix"
}

ACTIVE_FIX=$(setup_active_fixture)
OUT=$(bash "$SKILL_DIR/scan.sh" --base-dir "$ACTIVE_FIX")
assert_eq "$(echo "$OUT" | jq -r '.activeSessionIds | length')" "1" "active: 1 live session detected" || exit 1
assert_eq "$(echo "$OUT" | jq -r '.activeSessionIds[0]')" "live-session-uuid" "active: live-session-uuid" || exit 1

# ---------- Dynamic fixture: tierD (session-env, file-history, tasks, history.jsonl) ----------
setup_tierD_fixture() {
  # $$ = test runner PID, guaranteed alive during scan.sh child process.
  local fix="$SCRIPT_DIR/fixtures/tierD_dyn"
  rm -rf "$fix"
  mkdir -p "$fix"/{todos,shell-snapshots,debug,session-env,file-history,tasks,projects,sessions}
  echo '{}' > "$fix/settings.json"
  touch "$fix/history.jsonl"
  # active session
  cat > "$fix/sessions/$$.json" <<EOF
{"pid":$$,"sessionId":"active-uuid","cwd":"/tmp","startedAt":0,"kind":"interactive","entrypoint":"test"}
EOF
  # session-env: active 1 + orphan 2
  mkdir -p "$fix/session-env/active-uuid"
  mkdir -p "$fix/session-env/orphan-a"
  mkdir -p "$fix/session-env/orphan-b"
  # file-history
  mkdir -p "$fix/file-history/linked-uuid"
  mkdir -p "$fix/file-history/orphan-fh-1"
  mkdir -p "$fix/file-history/orphan-fh-2"
  mkdir -p "$fix/projects/-some-dir"
  touch "$fix/projects/-some-dir/linked-uuid.jsonl"
  # tasks
  mkdir -p "$fix/tasks/a" "$fix/tasks/b" "$fix/tasks/c"
  # history.jsonl: 5 old + 3 new lines
  local NOW_MS YEAR_AGO_MS
  NOW_MS=$(( $(date +%s) * 1000 ))
  YEAR_AGO_MS=$(( NOW_MS - 365*86400*1000 ))
  : > "$fix/history.jsonl"
  for i in 1 2 3 4 5; do
    echo "{\"display\":\"old$i\",\"timestamp\":$YEAR_AGO_MS}" >> "$fix/history.jsonl"
  done
  for i in 1 2 3; do
    echo "{\"display\":\"new$i\",\"timestamp\":$NOW_MS}" >> "$fix/history.jsonl"
  done
  echo "$fix"
}

TIERD_FIX=$(setup_tierD_fixture)
OUT=$(bash "$SKILL_DIR/scan.sh" --base-dir "$TIERD_FIX")
assert_eq "$(echo "$OUT" | jq -r .tierD.orphanSessionEnv)" "2" "tierD: orphan session-env=2" || exit 1
assert_eq "$(echo "$OUT" | jq -r .tierD.orphanFileHistory)" "2" "tierD: orphan file-history=2" || exit 1
assert_eq "$(echo "$OUT" | jq -r .tierD.allTasks)" "3" "tierD: allTasks=3" || exit 1
assert_eq "$(echo "$OUT" | jq -r .tierD.historyJsonlOldLines)" "5" "tierD: history old lines=5" || exit 1
assert_eq "$(echo "$OUT" | jq -r '.totalBytes.tierABC | type')" "number" "totalBytes.tierABC is number" || exit 1
assert_eq "$(echo "$OUT" | jq -r '.totalBytes.tierD | type')" "number" "totalBytes.tierD is number" || exit 1

echo "test_scan.sh: OK"
