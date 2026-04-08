#!/bin/bash
# PostToolUse Hook: gh issue create 成功後にプロジェクトステータスを自動設定
# デフォルトは Todo、コマンド内に CLAUDE_ISSUE_STATUS=in_progress が含まれていれば In Progress
# ステータスが未設定（空）のアイテムのみ対象
# exit 0 常時

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""' 2>/dev/null)

# gh issue create 以外は素通り
FIRST_LINE=$(echo "$CMD" | head -1)
if ! echo "$FIRST_LINE" | grep -qE '^\s*(CLAUDE_ISSUE_STATUS=\S+\s+)?gh\s+issue\s+create\b'; then
  exit 0
fi

# コマンドプレフィックスから意図を抽出: CLAUDE_ISSUE_STATUS=in_progress gh issue create ...
TARGET_STATUS="Todo"
if echo "$CMD" | grep -qE 'CLAUDE_ISSUE_STATUS=in_progress\b'; then
  TARGET_STATUS="In Progress"
fi

# Issue URL を抽出（stdout から）
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // ""' 2>/dev/null)
ISSUE_URL=$(echo "$STDOUT" | grep -oE 'https://github.com/[^/]+/[^/]+/issues/[0-9]+' | head -1)
if [ -z "$ISSUE_URL" ]; then
  exit 0
fi

ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
OWNER=$(echo "$ISSUE_URL" | sed 's|https://github.com/||' | cut -d'/' -f1)
REPO_NAME=$(echo "$ISSUE_URL" | sed 's|https://github.com/||' | cut -d'/' -f2)

# Issue のプロジェクトアイテムを取得（ステータス + フィールド情報を1回で）
# GitHub API の eventual consistency 対策でリトライ: projectItems が空なら最大 5 回リトライ
fetch_item_info() {
  gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) {
          projectItems(first: 5) {
            nodes {
              id
              project {
                id
                field(name: "Status") {
                  ... on ProjectV2SingleSelectField {
                    id
                    options { id name }
                  }
                }
              }
              fieldValueByName(name: "Status") {
                ... on ProjectV2ItemFieldSingleSelectValue { name }
              }
            }
          }
        }
      }
    }
  ' -f owner="$OWNER" -f repo="$REPO_NAME" -F number="$ISSUE_NUM" 2>/dev/null
}

ITEM_INFO=""
for attempt in 1 2 3 4 5; do
  ITEM_INFO=$(fetch_item_info)
  ITEM_COUNT=$(echo "$ITEM_INFO" | jq '.data.repository.issue.projectItems.nodes | length' 2>/dev/null)
  if [ -n "$ITEM_COUNT" ] && [ "$ITEM_COUNT" -gt 0 ]; then
    break
  fi
  # eventual consistency 待ち: 0.5s, 1s, 1.5s, 2s
  sleep "0.$((attempt * 5))"
done

if [ -z "$ITEM_INFO" ]; then
  exit 0
fi

# ステータスが未設定（null/空）のアイテムに目的ステータスを設定
echo "$ITEM_INFO" | jq -r --arg target "$TARGET_STATUS" '
  .data.repository.issue.projectItems.nodes[]?
  | select(.fieldValueByName.name == null or .fieldValueByName.name == "")
  | .id + "|" + .project.id + "|" + .project.field.id + "|" + (.project.field.options[]? | select(.name == $target) | .id)
' 2>/dev/null | while IFS='|' read -r ITEM_ID PROJECT_ID FIELD_ID OPTION_ID; do
  if [ -z "$ITEM_ID" ] || [ -z "$FIELD_ID" ] || [ -z "$OPTION_ID" ]; then
    continue
  fi

  gh api graphql -f query='
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
        value: { singleSelectOptionId: $optionId }
      }) { projectV2Item { id } }
    }
  ' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$FIELD_ID" -f optionId="$OPTION_ID" 2>/dev/null

  echo "Issue #${ISSUE_NUM} のプロジェクトステータスを ${TARGET_STATUS} に設定しました。"
done

exit 0
