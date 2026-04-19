#!/bin/bash
# PreToolUse: gh issue create に必須オプションが揃っていなければブロック

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

is_first_line_cmd "$CMD" '^\s*gh\s+issue\s+create\b' || exit 0

ERRORS=""

if ! echo "$CMD" | grep -qE '\-\-label'; then
  ERRORS="${ERRORS}--label が指定されていません。フェーズラベル + 重要度ラベルを付与してください。\n  例: --label \"開発,重要度:中\"\n  有効なフェーズ: ヒアリング / 見積もり / 開発 / テスト / 納品\n  有効な重要度: 重要度:高 / 重要度:中 / 重要度:低\n\n"
fi

if ! echo "$CMD" | grep -qE '\-\-assignee'; then
  ERRORS="${ERRORS}--assignee が指定されていません。\n  gh api user --jq '.login' でユーザー名を取得し、--assignee に設定してください。\n\n"
fi

if ! echo "$CMD" | grep -qE '\-\-project'; then
  ERRORS="${ERRORS}--project が指定されていません。\n  SessionStart で注入された「プロジェクト」一覧から該当プロジェクトを指定してください。\n\n"
fi

if [ -n "$ERRORS" ]; then
  {
    echo "gh issue create に必須オプションが不足しています:"
    echo ""
    echo -e "$ERRORS"
    echo "※ 作成前に SessionStart で注入された「オープン Issue」一覧を確認し、"
    echo "  同じ目的の Issue が既にないか確認してください。"
  } >&2
  exit 2
fi

echo "✓ Issue 作成チェック通過。重複 Issue がないことを確認済みですか？"
exit 0
