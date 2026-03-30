#!/bin/bash
# PostToolUse Hook: gh issue close / gh pr merge 成功後に Status → Done を自動更新
# exit 0 常時（リマインド型）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Bash ツール以外は素通り
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // ""' 2>/dev/null)

# --- Issue 番号の抽出 ---
ISSUE_NUMS=""

# 先頭行のみでコマンド種別を判定（コミットメッセージ内の文字列に誤反応しない）
FIRST_LINE=$(echo "$CMD" | head -1)

# gh issue close N
if echo "$FIRST_LINE" | grep -qE '^\s*gh\s+issue\s+close\b'; then
  ISSUE_NUMS=$(echo "$CMD" | grep -oE 'gh\s+issue\s+close\s+([0-9]+)' | grep -oE '[0-9]+')
fi

# gh pr merge (成功後に紐づく Issue を取得)
if echo "$FIRST_LINE" | grep -qE '^\s*gh\s+pr\s+merge\b'; then
  PR_NUM=$(echo "$CMD" | grep -oE 'gh\s+pr\s+merge\s+([0-9]+)' | grep -oE '[0-9]+')
  if [ -z "$PR_NUM" ]; then
    PR_NUM=$(gh pr view --json number --jq '.number' 2>/dev/null)
  fi
  if [ -n "$PR_NUM" ]; then
    PR_BODY=$(gh pr view "$PR_NUM" --json body --jq '.body' 2>/dev/null)
    ISSUE_NUMS=$(echo "$PR_BODY" | grep -oiE '(closes?|fix(es)?|resolves?)\s+#[0-9]+' | grep -oE '[0-9]+')
  fi
fi

if [ -z "$ISSUE_NUMS" ]; then
  exit 0
fi

# リポジトリ情報
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
  exit 0
fi
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

UPDATED_ISSUES=""
for ISSUE_NUM in $ISSUE_NUMS; do
  # Issue のプロジェクトアイテムを取得
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

  # ステータスが Done 以外のアイテムを更新
  echo "$ITEM_INFO" | jq -r '.data.repository.issue.projectItems.nodes[]? | select(.fieldValueByName.name != "Done") | .id + "|" + .project.id' 2>/dev/null | while IFS='|' read -r ITEM_ID PROJECT_ID; do
    if [ -z "$ITEM_ID" ] || [ -z "$PROJECT_ID" ]; then
      continue
    fi

    # Status フィールドの ID と "Done" オプション ID を取得
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
    DONE_ID=$(echo "$FIELD_INFO" | jq -r '.data.node.field.options[]? | select(.name == "Done") | .id' 2>/dev/null)

    if [ -z "$FIELD_ID" ] || [ -z "$DONE_ID" ]; then
      continue
    fi

    # ステータスを Done に更新
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
    ' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$FIELD_ID" -f optionId="$DONE_ID" 2>/dev/null

    UPDATED_ISSUES="${UPDATED_ISSUES} #${ISSUE_NUM}"
  done
done

if [ -n "$UPDATED_ISSUES" ]; then
  echo "Issue ステータスを Done に更新しました:${UPDATED_ISSUES}"
fi

exit 0
