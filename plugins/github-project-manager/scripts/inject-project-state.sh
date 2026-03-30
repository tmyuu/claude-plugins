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

# GitHub Projects（org → user fallback）+ 進捗サマリー
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)
if [ -n "$OWNER" ]; then
  echo "### プロジェクト"

  # プロジェクト一覧を取得（org → user fallback）
  ORG_RAW=$(gh api graphql -f query='{
    organization(login: "'"$OWNER"'") {
      projectsV2(first: 10, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes { title number id closed }
      }
    }
  }' 2>/dev/null)
  PROJECTS_JSON=$(echo "$ORG_RAW" | jq '.data.organization.projectsV2.nodes // empty' 2>/dev/null)

  if [ -z "$PROJECTS_JSON" ] || [ "$PROJECTS_JSON" = "null" ]; then
    PROJECTS_JSON=$(gh api graphql -f query='{
      viewer {
        projectsV2(first: 10, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes { title number id closed }
        }
      }
    }' 2>/dev/null | jq '.data.viewer.projectsV2.nodes // []' 2>/dev/null)
  fi

  # 各プロジェクトの進捗を表示
  if [ -n "$PROJECTS_JSON" ] && [ "$PROJECTS_JSON" != "null" ] && [ "$PROJECTS_JSON" != "[]" ]; then
    echo "$PROJECTS_JSON" | jq -r '.[] | "\(.id)|\(.title)|\(.number)|\(.closed)"' 2>/dev/null | while IFS='|' read -r PROJECT_ID TITLE NUMBER CLOSED; do
      if [ "$CLOSED" = "true" ]; then
        continue
      fi

      # プロジェクト内アイテムのステータスを集計
      ITEMS_RAW=$(gh api graphql -f query='
        query($projectId: ID!) {
          node(id: $projectId) {
            ... on ProjectV2 {
              items(first: 100) {
                nodes {
                  fieldValueByName(name: "Status") {
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      name
                    }
                  }
                }
              }
            }
          }
        }
      ' -f projectId="$PROJECT_ID" 2>/dev/null)

      TOTAL=$(echo "$ITEMS_RAW" | jq '[.data.node.items.nodes[]] | length' 2>/dev/null)
      DONE=$(echo "$ITEMS_RAW" | jq '[.data.node.items.nodes[] | select(.fieldValueByName.name == "Done")] | length' 2>/dev/null)
      IN_PROGRESS=$(echo "$ITEMS_RAW" | jq '[.data.node.items.nodes[] | select(.fieldValueByName.name == "In Progress")] | length' 2>/dev/null)
      TODO=$(echo "$ITEMS_RAW" | jq '[.data.node.items.nodes[] | select(.fieldValueByName.name == "Todo")] | length' 2>/dev/null)

      TOTAL=${TOTAL:-0}
      DONE=${DONE:-0}
      IN_PROGRESS=${IN_PROGRESS:-0}
      TODO=${TODO:-0}

      if [ "$TOTAL" -eq 0 ]; then
        echo "- ${TITLE} (#${NUMBER}) — アイテムなし"
      elif [ "$TOTAL" -eq "$DONE" ] && [ "$TOTAL" -gt 0 ]; then
        echo "- ${TITLE} (#${NUMBER}) — ${DONE}/${TOTAL} Done **全完了。クローズを検討してください**"
      else
        echo "- ${TITLE} (#${NUMBER}) — ${DONE}/${TOTAL} Done, ${IN_PROGRESS} In Progress, ${TODO} Todo"
      fi
    done
  else
    echo "（プロジェクトなし）"
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
