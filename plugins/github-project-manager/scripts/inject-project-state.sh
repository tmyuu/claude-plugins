#!/bin/bash
# SessionStart Hook: プロジェクト状態を Claude のコンテキストに注入
# stdout の内容が Claude のコンテキストに追加される

echo "## プロジェクト状態（自動注入）"
echo ""

# リポジトリ名
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
if [ -n "$REPO" ]; then
  echo "リポジトリ: $REPO"
  echo ""
fi

# GitHub Projects
ORG=$(echo "$REPO" | cut -d'/' -f1)
if [ -n "$ORG" ]; then
  echo "### プロジェクト"
  # org の場合
  gh api graphql -f query='{
    organization(login: "'"$ORG"'") {
      projectsV2(first: 10, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes { title number }
      }
    }
  }' --jq '.data.organization.projectsV2.nodes[] | "- \(.title) (#\(.number))"' 2>/dev/null
  # user の場合（org で取れなければ）
  if [ $? -ne 0 ]; then
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

# オープン Issue
echo "### オープン Issue"
gh issue list --state open --limit 30 \
  --json number,title,labels,assignees,milestone \
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
git log --oneline -5 2>/dev/null
