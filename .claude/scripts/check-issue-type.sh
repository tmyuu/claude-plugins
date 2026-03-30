#!/bin/bash
# PostToolUse Hook: gh issue create 成功後に Issue Type 設定をリマインド（org リポジトリのみ）
# stdout の内容が Claude のコンテキストに追加される

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""' 2>/dev/null)

# gh issue create 以外は素通り
if ! echo "$CMD" | grep -q 'gh issue create'; then
  exit 0
fi

# 成功していない場合はスキップ
if [ -z "$RESPONSE" ]; then
  exit 0
fi

# Issue URL を抽出
ISSUE_URL=$(echo "$RESPONSE" | grep -oE 'https://github.com/[^/]+/[^/]+/issues/[0-9]+' | head -1)
if [ -z "$ISSUE_URL" ]; then
  exit 0
fi

ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
OWNER=$(echo "$ISSUE_URL" | sed 's|https://github.com/||' | cut -d'/' -f1)
REPO_NAME=$(echo "$ISSUE_URL" | sed 's|https://github.com/||' | cut -d'/' -f2)

# org リポジトリかチェック（URL のオーナーで判定）
OWNER_TYPE=$(gh api "users/$OWNER" --jq '.type' 2>/dev/null)
if [ "$OWNER_TYPE" != "Organization" ]; then
  exit 0
fi

cat <<EOF
⚠ Issue #${ISSUE_NUM} に Issue Type を設定してください（Organization リポジトリ）。

手順:
1. gh api graphql -H "GraphQL-Features: issue_types" でタイプ一覧を取得
2. updateIssueIssueType mutation で設定

有効なタイプ: Task / Bug / Feature / Minutes / Acceptance
EOF

exit 0
