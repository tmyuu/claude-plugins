#!/bin/bash
# PostToolUse Hook: .ts/.tsx ファイル編集後に ESLint を自動実行
# エラーがあれば stdout で Claude にフィードバック

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

# ファイルに最も近い node_modules を探す（モノレポ対応）
DIR=$(dirname "$FILE")
ESLINT_BIN=""
while [ "$DIR" != "/" ] && [ "$DIR" != "." ]; do
  if [ -f "$DIR/node_modules/.bin/eslint" ]; then
    ESLINT_BIN="$DIR/node_modules/.bin/eslint"
    break
  fi
  DIR=$(dirname "$DIR")
done

# git root の node_modules もチェック
if [ -z "$ESLINT_BIN" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$ROOT" ] && [ -f "$ROOT/node_modules/.bin/eslint" ]; then
    ESLINT_BIN="$ROOT/node_modules/.bin/eslint"
  fi
fi

# ESLint が見つからなければスキップ
if [ -z "$ESLINT_BIN" ]; then
  exit 0
fi

# ESLint 実行（エラーは stdout で Claude にフィードバック）
RESULT=$("$ESLINT_BIN" --fix "$FILE" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] && [ -n "$RESULT" ]; then
  echo "ESLint: $FILE"
  echo "$RESULT" | head -20
fi

exit 0
