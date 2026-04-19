#!/bin/bash
# PreToolUse: git checkout -b / switch -c のブランチ名に Issue 番号があるか、
# かつその Issue が実在して open 状態かを検証

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

echo "$CMD" | grep -qE 'git checkout -b|git switch -c' || exit 0

BRANCH=$(echo "$CMD" | grep -oE '(-b|-c)\s+\S+' | awk '{print $2}')
[ -z "$BRANCH" ] && exit 0

# 特殊ブランチはスキップ
echo "$BRANCH" | grep -qE '^(main|master|develop|staging|production)$' && exit 0

# Issue 番号が含まれていない場合はブロック
if ! echo "$BRANCH" | grep -qE '#[0-9]+'; then
  cat >&2 <<'FEEDBACK'
ブランチ名に Issue 番号が含まれていません。

命名規則: feature/#N-description or fix/#N-description
例: feature/#20-search-function, fix/#16-webhook-validation

これにより GitHub が自動的に Development サイドバーにリンクします。
SessionStart で注入されたオープン Issue 一覧から該当 Issue を確認してください。
FEEDBACK
  exit 2
fi

# Issue 実在・状態検証（gh が使える場合のみ）
has_gh || exit 0

ISSUE_NUM=$(echo "$BRANCH" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | head -1)
STATE=$(get_issue_state "$ISSUE_NUM")

if [ -z "$STATE" ]; then
  cat >&2 <<FEEDBACK
ブランチ名の Issue #${ISSUE_NUM} がリポジトリに存在しません。

対応方法:
1. 正しい Issue 番号か確認してください
2. Issue が無ければ /new-issue で先に作成してください
FEEDBACK
  exit 2
fi

if [ "$STATE" = "CLOSED" ]; then
  TITLE=$(get_issue_title "$ISSUE_NUM")
  cat >&2 <<FEEDBACK
Issue #${ISSUE_NUM} は既にクローズされています: ${TITLE}

対応方法:
- 別件の作業であれば、/new-issue で新しい Issue を作成してください
- 再対応が必要な場合は、過去 Issue を参照した新規 Issue を立ててください
FEEDBACK
  exit 2
fi

exit 0
