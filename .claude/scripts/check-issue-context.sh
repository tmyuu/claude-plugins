#!/bin/bash
# PreToolUse Hook (Edit/Write): Issue 未確定状態でのソースコード編集をブロック
# main ブランチ上での編集 → Issue を確定しブランチを作成するよう促す
# feature ブランチ上での編集 → 素通り
# exit 0 = 続行, exit 2 = ブロック

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Edit / Write 以外は素通り
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

# 編集対象ファイルを取得
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# .claude/ 配下の設定ファイルは常に許可（Hook自体の開発を妨げない）
if echo "$FILE_PATH" | grep -qE '(^|/)\.claude/'; then
  exit 0
fi

# 設定ファイル系は許可（.gitignore, package.json 等）
BASENAME=$(basename "$FILE_PATH" 2>/dev/null)
case "$BASENAME" in
  .gitignore|.eslintrc*|.prettier*|*.config.*|*.json|*.toml|*.yaml|*.yml|*.md)
    exit 0
    ;;
esac

# 現在のブランチを確認
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -z "$BRANCH" ]; then
  exit 0
fi

# main/master 以外のブランチ: ステータスが Todo なら In Progress に自動遷移してから許可
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
  BRANCH_ISSUE=$(echo "$BRANCH" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | head -1)
  if [ -n "$BRANCH_ISSUE" ]; then
    STATUS_MARKER="/tmp/.claude-ip-checked-${BRANCH_ISSUE}"
    if [ ! -f "$STATUS_MARKER" ]; then
      REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
      OWNER=$(echo "$REPO" | cut -d'/' -f1)
      REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)
      if [ -n "$OWNER" ] && [ -n "$REPO_NAME" ]; then
        # 1回の GraphQL でステータス + フィールド情報を取得
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
        ' -f owner="$OWNER" -f repo="$REPO_NAME" -F number="$BRANCH_ISSUE" 2>/dev/null)

        # Todo のアイテムがあれば In Progress に遷移
        echo "$ITEM_INFO" | jq -r '.data.repository.issue.projectItems.nodes[]? | select(.fieldValueByName.name == "Todo") | .id + "|" + .project.id + "|" + .project.field.id + "|" + (.project.field.options[]? | select(.name == "In Progress") | .id)' 2>/dev/null | head -1 | while IFS='|' read -r ITEM_ID PROJECT_ID FIELD_ID IP_ID; do
          if [ -n "$ITEM_ID" ] && [ -n "$FIELD_ID" ] && [ -n "$IP_ID" ]; then
            gh api graphql -f query='
              mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
                updateProjectV2ItemFieldValue(input: {
                  projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
                  value: { singleSelectOptionId: $optionId }
                }) { projectV2Item { id } }
              }
            ' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$FIELD_ID" -f optionId="$IP_ID" 2>/dev/null
            echo "Issue #${BRANCH_ISSUE} のステータスを Todo → In Progress に自動更新しました。"
          fi
        done
      fi
      touch "$STATUS_MARKER"
    fi
  fi
  exit 0
fi

# main ブランチでソースコード編集 → ブロック
OPEN_ISSUES=$(gh issue list --limit 10 --state open --json number,title --jq '.[] | "  #\(.number) \(.title)"' 2>/dev/null)

cat >&2 <<FEEDBACK
main ブランチ上でのソースコード編集はワークフロー違反です。

手順:
1. この作業に対応する Issue を確認（既存 or /new-issue で新規作成）
2. feature ブランチを作成: git checkout -b feature/#N-description
3. ブランチ上でコーディングを開始

オープン Issue:
${OPEN_ISSUES:-  （なし — /new-issue で作成してください）}
FEEDBACK
exit 2
