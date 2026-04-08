#!/bin/bash
# PostToolUse Hook: gh issue create 成功後にプロジェクトへの追加 + ステータス設定を能動的に実行
# 1. コマンドの --project から project 名 → ID を解決
# 2. Issue の node_id を取得
# 3. addProjectV2ItemById で project に追加（idempotent: 既に追加されていても成功）
# 4. updateProjectV2ItemFieldValue で Status を設定
# デフォルトは Todo、コマンド先頭に CLAUDE_ISSUE_STATUS=in_progress があれば In Progress
# exit 0 常時

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# gh issue create 以外は素通り
FIRST_LINE=$(echo "$CMD" | head -1)
if ! echo "$FIRST_LINE" | grep -qE '^\s*(CLAUDE_ISSUE_STATUS=\S+\s+)?gh\s+issue\s+create\b'; then
  exit 0
fi

# 目的ステータスを決定
TARGET_STATUS="Todo"
if echo "$CMD" | grep -qE 'CLAUDE_ISSUE_STATUS=in_progress\b'; then
  TARGET_STATUS="In Progress"
fi

# Issue URL を stdout から抽出
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // ""' 2>/dev/null)
ISSUE_URL=$(echo "$STDOUT" | grep -oE 'https://github.com/[^/]+/[^/]+/issues/[0-9]+' | head -1)
if [ -z "$ISSUE_URL" ]; then
  exit 0
fi

ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
OWNER=$(echo "$ISSUE_URL" | sed 's|https://github.com/||' | cut -d'/' -f1)
REPO_NAME=$(echo "$ISSUE_URL" | sed 's|https://github.com/||' | cut -d'/' -f2)

# Issue の node_id を取得（addProjectV2ItemById に必要）
ISSUE_NODE_ID=$(gh api "repos/$OWNER/$REPO_NAME/issues/$ISSUE_NUM" --jq '.node_id' 2>/dev/null)
if [ -z "$ISSUE_NODE_ID" ]; then
  exit 0
fi

# --project の値を抽出（クォート対応）
PROJECT_NAME=$(echo "$CMD" | grep -oE '\-\-project\s+"[^"]+"' | sed 's/--project[[:space:]]*//' | tr -d '"')
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(echo "$CMD" | grep -oE "\-\-project\s+'[^']+'" | sed "s/--project[[:space:]]*//" | tr -d "'")
fi
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(echo "$CMD" | grep -oE '\-\-project\s+[^ ]+' | sed 's/--project[[:space:]]*//')
fi

if [ -z "$PROJECT_NAME" ]; then
  exit 0
fi

# プロジェクト ID + Status フィールド情報を取得（org → user fallback、1 query で全部）
PROJECTS_RAW=$(gh api graphql -f query="{
  organization(login: \"$OWNER\") {
    projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        id title closed
        field(name: \"Status\") {
          ... on ProjectV2SingleSelectField {
            id
            options { id name }
          }
        }
      }
    }
  }
}" 2>/dev/null)
PROJECT_INFO=$(echo "$PROJECTS_RAW" | jq --arg name "$PROJECT_NAME" \
  '.data.organization.projectsV2.nodes[]? | select(.title == $name and .closed == false)' 2>/dev/null)

if [ -z "$PROJECT_INFO" ]; then
  PROJECTS_RAW=$(gh api graphql -f query="{
    viewer {
      projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes {
          id title closed
          field(name: \"Status\") {
            ... on ProjectV2SingleSelectField {
              id
              options { id name }
            }
          }
        }
      }
    }
  }" 2>/dev/null)
  PROJECT_INFO=$(echo "$PROJECTS_RAW" | jq --arg name "$PROJECT_NAME" \
    '.data.viewer.projectsV2.nodes[]? | select(.title == $name and .closed == false)' 2>/dev/null)
fi

if [ -z "$PROJECT_INFO" ]; then
  exit 0
fi

PROJECT_ID=$(echo "$PROJECT_INFO" | jq -r '.id' 2>/dev/null)
FIELD_ID=$(echo "$PROJECT_INFO" | jq -r '.field.id // ""' 2>/dev/null)
OPTION_ID=$(echo "$PROJECT_INFO" | jq -r --arg target "$TARGET_STATUS" \
  '.field.options[]? | select(.name == $target) | .id' 2>/dev/null)

if [ -z "$PROJECT_ID" ] || [ -z "$FIELD_ID" ] || [ -z "$OPTION_ID" ]; then
  exit 0
fi

# addProjectV2ItemById で Issue を project に追加（idempotent: 既に追加済みでも item ID を返す）
ADD_RESULT=$(gh api graphql -f query='
  mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
      item { id }
    }
  }
' -f projectId="$PROJECT_ID" -f contentId="$ISSUE_NODE_ID" 2>/dev/null)

ITEM_ID=$(echo "$ADD_RESULT" | jq -r '.data.addProjectV2ItemById.item.id // ""' 2>/dev/null)
if [ -z "$ITEM_ID" ]; then
  exit 0
fi

# Status を設定
gh api graphql -f query='
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
      value: { singleSelectOptionId: $optionId }
    }) { projectV2Item { id } }
  }
' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$FIELD_ID" -f optionId="$OPTION_ID" 2>/dev/null

echo "Issue #${ISSUE_NUM} のプロジェクトステータスを ${TARGET_STATUS} に設定しました。"

exit 0
