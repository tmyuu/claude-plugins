#!/bin/bash
# PreToolUse Hook: git commit に Issue 番号があるかチェック
# exit 0 = 続行, exit 2 = ブロック（stderr が Claude にフィードバックされ自己修正を促す）

# jq が必要
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# git commit 以外は素通り（gh issue create 等の誤検知を防止）
if ! echo "$CMD" | grep -qE '^\s*git\s+commit\b'; then
  exit 0
fi

# --amend は既存コミットの修正なのでスキップ
if echo "$CMD" | grep -qF -- '--amend'; then
  exit 0
fi

# Issue 番号パターン: (#N) または Closes #N / Refs #N 形式
# (#N) — 括弧で囲まれた Issue 番号（偽陽性防止: CSS #333 等を除外）
if echo "$CMD" | grep -qE '\(#[0-9]+\)'; then
  exit 0
fi

# Closes/Fixes/Refs #N パターン
if echo "$CMD" | grep -qiE '(closes?|fix(es)?|refs?|resolves?)\s+#[0-9]+'; then
  exit 0
fi

# ブロック: stderr にフィードバック → Claude が自己修正
cat >&2 <<'FEEDBACK'
コミットメッセージに Issue 番号が含まれていません。

Issue 番号の書き方:
- 括弧付き: "ログイン機能を実装 (#20)"
- Closes: "Closes #20"

対応方法:
1. SessionStart で注入された「オープン Issue」一覧から該当 Issue を特定
2. コミットメッセージに Issue 番号を含めて再実行
3. 該当する Issue がなければ、先に Issue を作成
FEEDBACK
exit 2
