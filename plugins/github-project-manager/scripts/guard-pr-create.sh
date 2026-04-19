#!/bin/bash
# PreToolUse: gh pr create に必須オプション（label/assignee/project/Closes #N）が揃っていなければブロック

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

is_first_line_cmd "$CMD" '^\s*gh\s+pr\s+create\b' || exit 0

ERRORS=""

if ! echo "$CMD" | grep -qE '\-\-label'; then
  ERRORS="${ERRORS}--label が指定されていません。対応 Issue と同じラベルを付与してください。\n  例: --label \"開発,重要度:中\"\n\n"
fi

if ! echo "$CMD" | grep -qE '\-\-assignee'; then
  ERRORS="${ERRORS}--assignee が指定されていません。\n  gh api user --jq '.login' でユーザー名を取得し、--assignee に設定してください。\n\n"
fi

if ! echo "$CMD" | grep -qE '\-\-project'; then
  ERRORS="${ERRORS}--project が指定されていません。対応 Issue と同じプロジェクトに紐付けてください。\n  SessionStart で注入された「プロジェクト」一覧から該当プロジェクトを指定してください。\n\n"
fi

if ! echo "$CMD" | grep -qiE '(closes?|fix(es)?|resolves?)\s+#[0-9]+'; then
  ERRORS="${ERRORS}PR 本文に Closes #N が含まれていません。\n  対応 Issue を自動クローズするため、--body に \"Closes #N\" を記載してください。\n\n"
fi

if [ -n "$ERRORS" ]; then
  {
    echo "gh pr create に必須オプションが不足しています:"
    echo ""
    echo -e "$ERRORS"
  } >&2
  exit 2
fi

exit 0
