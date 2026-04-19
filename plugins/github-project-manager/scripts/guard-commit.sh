#!/bin/bash
# PreToolUse: git commit メッセージに Issue 番号がなければブロック
# exit 2 = ブロック（stderr が Claude にフィードバックされる）

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

# git commit 以外は素通り
is_first_line_cmd "$CMD" '^\s*git\s+commit\b' || exit 0

# --amend は既存コミットの修正なのでスキップ
echo "$CMD" | grep -qF -- '--amend' && exit 0

# (#N) または Closes/Fixes/Refs/Resolves #N を許容
if echo "$CMD" | grep -qE '\(#[0-9]+\)'; then
  exit 0
fi
if echo "$CMD" | grep -qiE '(closes?|fix(es)?|refs?|resolves?)\s+#[0-9]+'; then
  exit 0
fi

cat >&2 <<'FEEDBACK'
コミットメッセージに Issue 番号が含まれていません。

書き方:
- 括弧付き: "ログイン機能を実装 (#20)"
- Closes: "Closes #20"

対応方法:
1. SessionStart で注入された「オープン Issue」一覧から該当 Issue を特定
2. コミットメッセージに Issue 番号を含めて再実行
3. 該当する Issue がなければ、先に /new-issue で Issue を作成
FEEDBACK
exit 2
