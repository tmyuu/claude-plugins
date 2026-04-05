#!/bin/bash
# PostToolUse Hook: gh issue create 成功後にプロジェクトステータスを Todo に自動設定
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
if ! echo "$FIRST_LINE" | grep -qE '^\s*gh\s+issue\s+create\b'; then
  exit 0
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
ITEM_INFO=$(gh api graphql -f query='
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
' -f owner="$OWNER" -f repo="$REPO_NAME" -F number="$ISSUE_NUM" 2>/dev/null)

if [ -z "$ITEM_INFO" ]; then
  exit 0
fi

# ステータスが未設定（null/空）のアイテムに Todo を設定
echo "$ITEM_INFO" | jq -r '
  .data.repository.issue.projectItems.nodes[]?
  | select(.fieldValueByName.name == null or .fieldValueByName.name == "")
  | .id + "|" + .project.id + "|" + .project.field.id + "|" + (.project.field.options[]? | select(.name == "Todo") | .id)
' 2>/dev/null | while IFS='|' read -r ITEM_ID PROJECT_ID FIELD_ID TODO_ID; do
  if [ -z "$ITEM_ID" ] || [ -z "$FIELD_ID" ] || [ -z "$TODO_ID" ]; then
    continue
  fi

  gh api graphql -f query='
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
        value: { singleSelectOptionId: $optionId }
      }) { projectV2Item { id } }
    }
  ' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$FIELD_ID" -f optionId="$TODO_ID" 2>/dev/null

  echo "Issue #${ISSUE_NUM} のプロジェクトステータスを Todo に設定しました。"
done

exit 0
