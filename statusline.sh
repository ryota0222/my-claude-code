#!/bin/bash
input=$(cat)

PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"
fi

FILLED=$((PCT / 10))
EMPTY=$((10 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '█')$(printf "%${EMPTY}s" | tr ' ' '░')

# ---- duration formatting (h/m/s) ----
TOTAL_SECS=$((DURATION_MS / 1000))
HRS=$((TOTAL_SECS / 3600))
MINS=$(((TOTAL_SECS % 3600) / 60))
SECS=$((TOTAL_SECS % 60))

if [ "$HRS" -gt 0 ]; then
  # 1h 05m 09s の形式（分・秒はゼロ埋め）
  DURATION_STR=$(printf "%dh %02dm %02ds" "$HRS" "$MINS" "$SECS")
else
  # 12m 34s の形式
  DURATION_STR=$(printf "%dm %02ds" "$MINS" "$SECS")
fi
# -----------------------------------

echo "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ⏱️ ${DURATION_STR}"