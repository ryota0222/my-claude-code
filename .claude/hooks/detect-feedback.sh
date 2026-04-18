#!/bin/bash

cat > /dev/null

echo '{"additionalContext": "ユーザーのメッセージに修正指示やフィードバックが含まれている場合は、対応完了後に capture-feedback スキルを呼び出して tmp/rejections.jsonl に記録してください。"}'

exit 0
