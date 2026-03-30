#!/bin/bash
# PreToolUse Hook: git checkout -b のブランチ名に Issue 番号があるかチェック

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# git checkout -b 以外は素通り
if ! echo "$CMD" | grep -qE 'git checkout -b|git switch -c'; then
  exit 0
fi

# ブランチ名を抽出
BRANCH=$(echo "$CMD" | grep -oE '(-b|-c)\s+\S+' | awk '{print $2}')
if [ -z "$BRANCH" ]; then
  exit 0
fi

# main/develop 等の特殊ブランチはスキップ
if echo "$BRANCH" | grep -qE '^(main|master|develop|staging|production)$'; then
  exit 0
fi

# Issue 番号（#N）があるかチェック
if echo "$BRANCH" | grep -qE '#[0-9]+'; then
  exit 0
fi

# ブロック
cat >&2 <<FEEDBACK
ブランチ名に Issue 番号が含まれていません。

命名規則: feature/#N-description or fix/#N-description
例: feature/#20-search-function, fix/#16-webhook-validation

これにより GitHub が自動的に Development サイドバーにリンクします。
SessionStart で注入されたオープン Issue 一覧から該当 Issue を確認してください。
FEEDBACK
exit 2
