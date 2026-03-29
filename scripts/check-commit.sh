#!/bin/bash
# PreToolUse Hook: git commit に Issue 番号があるかチェック
# exit 0 = 続行, exit 2 = ブロック（stderr が Claude にフィードバックされ自己修正を促す）

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# git commit 以外は素通り
if ! echo "$CMD" | grep -q 'git commit'; then
  exit 0
fi

# --amend は既存コミットの修正なのでスキップ
if echo "$CMD" | grep -q '\-\-amend'; then
  exit 0
fi

# Issue 番号（#N）または Co-Authored-By があるかチェック
if echo "$CMD" | grep -qE '#[0-9]+'; then
  exit 0
fi

# Closes #N パターン
if echo "$CMD" | grep -qiE 'closes? #[0-9]+'; then
  exit 0
fi

# ブロック: stderr にフィードバック → Claude が自己修正
cat >&2 <<'FEEDBACK'
コミットメッセージに Issue 番号（#N）が含まれていません。

対応方法:
1. SessionStart で注入された「オープン Issue」一覧から該当 Issue を特定
2. コミットメッセージに Issue 番号を含めて再実行
   例: git commit -m "ログイン機能を実装 (#20)"
3. 該当する Issue がなければ、先に /new-issue で Issue を作成
FEEDBACK
exit 2
