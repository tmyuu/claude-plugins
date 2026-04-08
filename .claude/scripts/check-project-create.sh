#!/bin/bash
# PreToolUse Hook: プロジェクト新規作成時に既存プロジェクトを提示しリマインド
# 既存プロジェクトのテーマに合うならそちらを使うべき。逸脱時のみ新規作成。
# exit 0 常時（リマインド型）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

FIRST_LINE=$(echo "$CMD" | head -1)

# gh project create / createProjectV2 以外は素通り
if ! echo "$FIRST_LINE" | grep -qE '(gh\s+project\s+create|createProjectV2)'; then
  exit 0
fi

# リポジトリにリンクされた既存プロジェクトを取得
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
OWNER=$(echo "$REPO" | cut -d'/' -f1)

PROJECTS_JSON=$(gh api graphql -f query="{
  organization(login: \"$OWNER\") {
    projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes { title closed repositories(first: 50) { nodes { nameWithOwner } } }
    }
  }
}" 2>/dev/null | jq '.data.organization.projectsV2.nodes // empty' 2>/dev/null)

if [ -z "$PROJECTS_JSON" ] || [ "$PROJECTS_JSON" = "null" ]; then
  PROJECTS_JSON=$(gh api graphql -f query="{
    viewer {
      projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes { title closed repositories(first: 50) { nodes { nameWithOwner } } }
      }
    }
  }" 2>/dev/null | jq '.data.viewer.projectsV2.nodes // []' 2>/dev/null)
fi

LINKED=$(echo "$PROJECTS_JSON" | jq -r --arg repo "$REPO" \
  '.[] | select(.closed == false) | select(.repositories.nodes[]?.nameWithOwner == $repo) | "  - \(.title)"' 2>/dev/null)

if [ -n "$LINKED" ]; then
  cat <<REMINDER
⚠ このリポジトリ (${REPO}) には既に以下のプロジェクトがリンクされています:
${LINKED}

【作成前の確認】
1. 既存プロジェクトのテーマに合う場合は **必ず既存を使ってください**
2. テーマが明らかに逸脱している場合のみ新規作成
3. 判断に迷う場合はユーザーに確認

【作成後の必須作業】
- auto-link-project.sh が自動でリポジトリをリンクします
- **Default repository は API で設定不可**のため、作成後にユーザーに GitHub UI での設定を依頼してください
  (https://github.com/orgs/${OWNER}/projects/N/settings)
REMINDER
else
  cat <<REMINDER
このリポジトリ (${REPO}) にリンクされたプロジェクトはありません。新規作成します。

【作成後の必須作業】
- auto-link-project.sh が自動でリポジトリをリンクします
- **Default repository は API で設定不可**のため、作成後にユーザーに GitHub UI での設定を依頼してください
  (https://github.com/orgs/${OWNER}/projects/N/settings)
REMINDER
fi

exit 0
