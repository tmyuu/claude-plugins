#!/bin/bash
# PostToolUse Hook: gh project create / createProjectV2 成功後に
# 現在のリポジトリを自動リンク + Default repository 設定を促す
# exit 0 常時

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# gh project create / createProjectV2 以外は素通り
FIRST_LINE=$(echo "$CMD" | head -1)
if ! echo "$FIRST_LINE" | grep -qE '(gh\s+project\s+create|createProjectV2)'; then
  exit 0
fi

# リポジトリ情報
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
  exit 0
fi
OWNER=$(echo "$REPO" | cut -d'/' -f1)

# リポジトリの node_id
REPO_ID=$(gh api "repos/$REPO" --jq '.node_id' 2>/dev/null)
if [ -z "$REPO_ID" ]; then
  exit 0
fi

# 最新のプロジェクトを取得（user → org fallback）
LATEST=$(gh api graphql -f query='{
  viewer {
    projectsV2(first: 1, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes { id title number }
    }
  }
}' 2>/dev/null)
PROJECT_ID=$(echo "$LATEST" | jq -r '.data.viewer.projectsV2.nodes[0].id // ""' 2>/dev/null)
PROJECT_TITLE=$(echo "$LATEST" | jq -r '.data.viewer.projectsV2.nodes[0].title // ""' 2>/dev/null)
PROJECT_NUMBER=$(echo "$LATEST" | jq -r '.data.viewer.projectsV2.nodes[0].number // ""' 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
  LATEST=$(gh api graphql -f query="{
    organization(login: \"$OWNER\") {
      projectsV2(first: 1, orderBy: {field: CREATED_AT, direction: DESC}) {
        nodes { id title number }
      }
    }
  }" 2>/dev/null)
  PROJECT_ID=$(echo "$LATEST" | jq -r '.data.organization.projectsV2.nodes[0].id // ""' 2>/dev/null)
  PROJECT_TITLE=$(echo "$LATEST" | jq -r '.data.organization.projectsV2.nodes[0].title // ""' 2>/dev/null)
  PROJECT_NUMBER=$(echo "$LATEST" | jq -r '.data.organization.projectsV2.nodes[0].number // ""' 2>/dev/null)
fi

if [ -z "$PROJECT_ID" ]; then
  exit 0
fi

# リポジトリをプロジェクトにリンク
RESULT=$(gh api graphql -f query='
  mutation($projectId: ID!, $repositoryId: ID!) {
    linkProjectV2ToRepository(input: {
      projectId: $projectId
      repositoryId: $repositoryId
    }) {
      repository { nameWithOwner }
    }
  }
' -f projectId="$PROJECT_ID" -f repositoryId="$REPO_ID" 2>/dev/null)

if echo "$RESULT" | jq -e '.data.linkProjectV2ToRepository.repository' &>/dev/null; then
  cat <<EOF
✓ プロジェクト「${PROJECT_TITLE}」にリポジトリ ${REPO} を自動リンクしました。

⚠ Default repository は API で設定できません。以下の URL から手動で設定してください:
   https://github.com/orgs/${OWNER}/projects/${PROJECT_NUMBER}/settings
   → Default repository に ${REPO} を設定
EOF
fi

exit 0
