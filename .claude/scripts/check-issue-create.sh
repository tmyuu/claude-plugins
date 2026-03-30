#!/bin/bash
# PreToolUse Hook: gh issue create に --label と --assignee があるかチェック
# exit 0 = 続行, exit 2 = ブロック（stderr が Claude にフィードバックされ自己修正を促す）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# gh issue create 以外は素通り
if ! echo "$CMD" | grep -q 'gh issue create'; then
  exit 0
fi

ERRORS=""

# --label チェック
if ! echo "$CMD" | grep -qE '\-\-label'; then
  ERRORS="${ERRORS}--label が指定されていません。フェーズラベル + 重要度ラベルを付与してください。\n  例: --label \"開発,重要度:中\"\n  有効なフェーズ: ヒアリング / 見積もり / 開発 / テスト / 納品\n  有効な重要度: 重要度:高 / 重要度:中 / 重要度:低\n\n"
fi

# --assignee チェック
if ! echo "$CMD" | grep -qE '\-\-assignee'; then
  ERRORS="${ERRORS}--assignee が指定されていません。\n  gh api user --jq '.login' でユーザー名を取得し、--assignee に設定してください。\n\n"
fi

# --project チェック
if ! echo "$CMD" | grep -qE '\-\-project'; then
  ERRORS="${ERRORS}--project が指定されていません。\n  SessionStart で注入された「プロジェクト」一覧から該当プロジェクトを指定してください。\n\n"
fi

if [ -n "$ERRORS" ]; then
  echo "gh issue create に必須オプションが不足しています:" >&2
  echo "" >&2
  echo -e "$ERRORS" >&2
  exit 2
fi

exit 0
