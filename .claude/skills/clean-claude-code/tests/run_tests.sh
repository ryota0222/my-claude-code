#!/usr/bin/env bash
# Test runner for clean-claude-code
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0; FAIL=0
for t in "$SCRIPT_DIR"/test_*.sh; do
  echo "=== $(basename "$t") ==="
  if bash "$t"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
done
echo "---"
echo "PASS: $PASS, FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
