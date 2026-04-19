#!/bin/bash
# PostToolUse: gh issue create 成功後、org リポジトリなら Issue Type 設定をリマインド

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)
RESPONSE=$(echo "$INPUT" | read_tool_response_raw)

is_first_line_cmd "$CMD" '^\s*gh\s+issue\s+create\b' || exit 0
[ -z "$RESPONSE" ] && exit 0

ISSUE_URL=$(echo "$RESPONSE" | grep -oE 'https://github.com/[^/]+/[^/]+/issues/[0-9]+' | head -1)
[ -z "$ISSUE_URL" ] && exit 0

ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
URL_OWNER=$(echo "$ISSUE_URL" | sed 's|https://github.com/||' | cut -d'/' -f1)

OWNER_TYPE=$(gh api "users/$URL_OWNER" --jq '.type' 2>/dev/null)
[ "$OWNER_TYPE" != "Organization" ] && exit 0

cat <<EOF
⚠ Issue #${ISSUE_NUM} に Issue Type を設定してください（Organization リポジトリ）。

手順:
1. gh api graphql -H "GraphQL-Features: issue_types" でタイプ一覧を取得
2. updateIssueIssueType mutation で設定

有効なタイプ: Task / Bug / Feature / Minutes / Acceptance
EOF

exit 0
