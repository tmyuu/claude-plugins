#!/bin/bash
# SessionStart Hook: プロジェクト状態を Claude のコンテキストに注入
# stdout の内容が Claude のコンテキストに追加される

# 前提条件チェック
if ! command -v gh &>/dev/null; then
  echo "⚠ gh CLI が見つかりません"
  exit 0
fi
if ! gh auth status &>/dev/null; then
  echo "⚠ gh CLI が未認証です"
  exit 0
fi

echo "## プロジェクト状態（自動注入）"
echo ""

# リポジトリ名
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
if [ -n "$REPO" ]; then
  echo "リポジトリ: $REPO"
  echo ""
fi

# GitHub Projects（org → user fallback）
OWNER=$(echo "$REPO" | cut -d'/' -f1)
if [ -n "$OWNER" ]; then
  echo "### プロジェクト"
  # org で試行
  ORG_PROJECTS=$(gh api graphql -f query='{
    organization(login: "'"$OWNER"'") {
      projectsV2(first: 10, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes { title number }
      }
    }
  }' --jq '.data.organization.projectsV2.nodes[] | "- \(.title) (#\(.number))"' 2>/dev/null)

  if [ -n "$ORG_PROJECTS" ]; then
    echo "$ORG_PROJECTS"
  else
    # user で fallback（出力の空チェックで判定）
    gh api graphql -f query='{
      viewer {
        projectsV2(first: 10, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes { title number }
        }
      }
    }' --jq '.data.viewer.projectsV2.nodes[] | "- \(.title) (#\(.number))"' 2>/dev/null
  fi
  echo ""
fi

# オープン Issue（15件に制限）
echo "### オープン Issue"
gh issue list --state open --limit 15 \
  --json number,title,labels,assignees \
  --jq '.[] | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title) @\(.assignees | map(.login) | join(","))"' 2>/dev/null
echo ""

# 直近完了
echo "### 最近完了 (5件)"
gh issue list --state closed --limit 5 \
  --json number,title,closedAt \
  --jq '.[] | "#\(.number) \(.title) (\(.closedAt[:10]))"' 2>/dev/null
echo ""

# Git 状態
echo "### Git"
echo "branch: $(git branch --show-current 2>/dev/null)"
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "uncommitted: ${UNCOMMITTED}件"
if [ "$UNCOMMITTED" -gt 0 ] && [ "$UNCOMMITTED" -lt 10 ]; then
  git status --porcelain 2>/dev/null
fi
echo ""
echo "recent:"
git log --oneline -3 2>/dev/null
