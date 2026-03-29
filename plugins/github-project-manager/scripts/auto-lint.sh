#!/bin/bash
# PostToolUse Hook: .ts ファイル編集後に ESLint を自動実行

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)

# .ts/.tsx ファイル以外は無視
if ! echo "$FILE" | grep -qE '\.(ts|tsx)$'; then
  exit 0
fi

# ファイル存在チェック
if [ ! -f "$FILE" ]; then
  exit 0
fi

# プロジェクトルートに移動して ESLint 実行
ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$ROOT" ]; then
  exit 0
fi

cd "$ROOT" || exit 0

# eslint が存在する場合のみ実行
if command -v npx &>/dev/null && [ -f "node_modules/.bin/eslint" ]; then
  npx eslint --fix "$FILE" 2>/dev/null
fi

exit 0
