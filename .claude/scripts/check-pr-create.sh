#!/bin/bash
# PreToolUse Hook: gh pr create に必須オプションがあるかチェック
# --label, --assignee, --project, Closes #N を検証
# exit 0 = 続行, exit 2 = ブロック（stderr が Claude にフィードバックされ自己修正を促す）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# gh pr create 以外は素通り（コミットメッセージ内の文字列に誤反応しないよう先頭行のみ判定）
FIRST_LINE=$(echo "$CMD" | head -1)
if ! echo "$FIRST_LINE" | grep -qE '^\s*gh\s+pr\s+create\b'; then
  exit 0
fi

ERRORS=""

# --label チェック（Issue と同じラベル体系）
if ! echo "$CMD" | grep -qE '\-\-label'; then
  ERRORS="${ERRORS}--label が指定されていません。対応 Issue と同じラベルを付与してください。\n  例: --label \"開発,重要度:中\"\n\n"
fi

# --assignee チェック
if ! echo "$CMD" | grep -qE '\-\-assignee'; then
  ERRORS="${ERRORS}--assignee が指定されていません。\n  gh api user --jq '.login' でユーザー名を取得し、--assignee に設定してください。\n\n"
fi

# --project チェック（Issue と同じプロジェクトに紐付け）
if ! echo "$CMD" | grep -qE '\-\-project'; then
  ERRORS="${ERRORS}--project が指定されていません。対応 Issue と同じプロジェクトに紐付けてください。\n  SessionStart で注入された「プロジェクト」一覧から該当プロジェクトを指定してください。\n\n"
fi

# Closes #N チェック（--body 内に含まれているか）
if ! echo "$CMD" | grep -qiE '(closes?|fix(es)?|resolves?)\s+#[0-9]+'; then
  ERRORS="${ERRORS}PR 本文に Closes #N が含まれていません。\n  対応 Issue を自動クローズするため、--body に \"Closes #N\" を記載してください。\n\n"
fi

if [ -n "$ERRORS" ]; then
  echo "gh pr create に必須オプションが不足しています:" >&2
  echo "" >&2
  echo -e "$ERRORS" >&2
  exit 2
fi

exit 0
