#!/bin/bash

INPUT=$(cat)

# Skip if not rejected
WAS_REJECTED=$(echo "$INPUT" | jq -r '.was_rejected // false')
if [ "$WAS_REJECTED" != "true" ]; then
  exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
REJECTION_REASON=$(echo "$INPUT" | jq -r '.rejection_reason // empty')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure tmp directory exists
mkdir -p "$CLAUDE_PROJECT_DIR/tmp"

# Append rejection entry in JSONL format
echo "{\"timestamp\":\"$TIMESTAMP\",\"type\":\"rejection\",\"tool\":\"$TOOL_NAME\",\"file_path\":\"$FILE_PATH\",\"reason\":\"$REJECTION_REASON\"}" \
  >> "$CLAUDE_PROJECT_DIR/tmp/rejections.jsonl"

# Notify Claude Code that a rejection was recorded
echo '{"additionalContext": "拒否理由が tmp/rejections.jsonl に記録されました。同種の拒否が繰り返されている場合は analyze-rejections スキルを発動してルール化を検討してください。"}'

exit 0
