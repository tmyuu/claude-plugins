#!/bin/bash
# PostToolUse Hook: git commit 成功後に Issue ステータスを In Progress に自動更新
# exit 0 常時（リマインド型）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# git commit 以外は素通り
if ! echo "$CMD" | grep -qE '^\s*git\s+commit\b'; then
  exit 0
fi

# --amend はスキップ
if echo "$CMD" | grep -qF -- '--amend'; then
  exit 0
fi

# コミットメッセージから Issue 番号を抽出
ISSUE_NUMS=$(echo "$CMD" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | sort -u)

if [ -z "$ISSUE_NUMS" ]; then
  exit 0
fi

# リポジトリ情報を取得
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
  exit 0
fi

OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

UPDATED_ISSUES=""
for ISSUE_NUM in $ISSUE_NUMS; do
  # Issue の現在のプロジェクトステータスを取得
  ITEM_INFO=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) {
          projectItems(first: 5) {
            nodes {
              id
              project { id title }
              fieldValueByName(name: "Status") {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  optionId
                }
              }
            }
          }
        }
      }
    }
  ' -f owner="$OWNER" -f repo="$REPO_NAME" -F number="$ISSUE_NUM" 2>/dev/null)

  if [ -z "$ITEM_INFO" ]; then
    continue
  fi

  # 各プロジェクトアイテムのステータスを確認
  echo "$ITEM_INFO" | jq -r '.data.repository.issue.projectItems.nodes[]? | select(.fieldValueByName.name == "Todo") | .id + "|" + .project.id' 2>/dev/null | while IFS='|' read -r ITEM_ID PROJECT_ID; do
    if [ -z "$ITEM_ID" ] || [ -z "$PROJECT_ID" ]; then
      continue
    fi

    # Status フィールドの ID と "In Progress" オプション ID を取得
    FIELD_INFO=$(gh api graphql -f query='
      query($projectId: ID!) {
        node(id: $projectId) {
          ... on ProjectV2 {
            field(name: "Status") {
              ... on ProjectV2SingleSelectField {
                id
                options { id name }
              }
            }
          }
        }
      }
    ' -f projectId="$PROJECT_ID" 2>/dev/null)

    FIELD_ID=$(echo "$FIELD_INFO" | jq -r '.data.node.field.id // ""' 2>/dev/null)
    IN_PROGRESS_ID=$(echo "$FIELD_INFO" | jq -r '.data.node.field.options[]? | select(.name == "In Progress") | .id' 2>/dev/null)

    if [ -z "$FIELD_ID" ] || [ -z "$IN_PROGRESS_ID" ]; then
      continue
    fi

    # ステータスを In Progress に更新
    gh api graphql -f query='
      mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
        updateProjectV2ItemFieldValue(input: {
          projectId: $projectId
          itemId: $itemId
          fieldId: $fieldId
          value: { singleSelectOptionId: $optionId }
        }) {
          projectV2Item { id }
        }
      }
    ' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$FIELD_ID" -f optionId="$IN_PROGRESS_ID" 2>/dev/null

    UPDATED_ISSUES="${UPDATED_ISSUES} #${ISSUE_NUM}"
  done
done

if [ -n "$UPDATED_ISSUES" ]; then
  echo "Issue ステータスを In Progress に更新しました:${UPDATED_ISSUES}"
fi

exit 0
