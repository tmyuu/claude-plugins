#!/bin/bash
# SessionStart Hook: プロジェクト状態を Claude のコンテキストに包括的に注入
# Claude が整合性を判断し、矛盾があればバックグラウンドで修復できるよう全状態を出力する
# stdout の内容が Claude のコンテキストに追加される

# 前提条件チェック
if ! command -v gh &>/dev/null; then
  echo "⚠ gh CLI が見つかりません"
  exit 0
fi
if ! command -v jq &>/dev/null; then
  echo "⚠ jq が見つかりません"
  exit 0
fi
if ! gh auth status &>/dev/null 2>&1; then
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

OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

# === プロジェクト（全件: Open / Closed 両方） ===
if [ -n "$OWNER" ]; then
  echo "### プロジェクト"

  # プロジェクト一覧を取得（org → user fallback）
  ORG_RAW=$(gh api graphql -f query='{
    organization(login: "'"$OWNER"'") {
      projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes { title number id closed }
      }
    }
  }' 2>/dev/null)
  PROJECTS_JSON=$(echo "$ORG_RAW" | jq '.data.organization.projectsV2.nodes // empty' 2>/dev/null)

  if [ -z "$PROJECTS_JSON" ] || [ "$PROJECTS_JSON" = "null" ]; then
    PROJECTS_JSON=$(gh api graphql -f query='{
      viewer {
        projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes { title number id closed }
        }
      }
    }' 2>/dev/null | jq '.data.viewer.projectsV2.nodes // []' 2>/dev/null)
  fi

  if [ -n "$PROJECTS_JSON" ] && [ "$PROJECTS_JSON" != "null" ] && [ "$PROJECTS_JSON" != "[]" ]; then
    echo "$PROJECTS_JSON" | jq -r '.[] | "\(.id)|\(.title)|\(.number)|\(.closed)"' 2>/dev/null | while IFS='|' read -r PROJECT_ID TITLE NUMBER CLOSED; do
      if [ -z "$PROJECT_ID" ]; then
        continue
      fi

      # 1回の GraphQL でアイテム（Issue 状態含む）+ リポリンクを取得
      PROJECT_DETAIL=$(gh api graphql -f query='
        query($projectId: ID!) {
          node(id: $projectId) {
            ... on ProjectV2 {
              repositories(first: 50) {
                nodes { nameWithOwner }
              }
              items(first: 100) {
                nodes {
                  fieldValueByName(name: "Status") {
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      name
                    }
                  }
                  content {
                    ... on Issue {
                      number
                      state
                      repository { nameWithOwner }
                    }
                  }
                }
              }
            }
          }
        }
      ' -f projectId="$PROJECT_ID" 2>/dev/null)

      # リポリンク状態
      REPO_LINKED=$(echo "$PROJECT_DETAIL" | jq -r ".data.node.repositories.nodes[]? | select(.nameWithOwner == \"$REPO\") | .nameWithOwner" 2>/dev/null)
      if [ -n "$REPO_LINKED" ]; then
        LINK_STATUS="リポリンク:✓"
      else
        LINK_STATUS="リポリンク:✗"
      fi

      # このリポジトリのアイテムのみ集計
      REPO_ITEMS=$(echo "$PROJECT_DETAIL" | jq "[.data.node.items.nodes[] | select(.content.repository.nameWithOwner == \"$REPO\")]" 2>/dev/null)
      TOTAL=$(echo "$REPO_ITEMS" | jq 'length' 2>/dev/null)
      DONE=$(echo "$REPO_ITEMS" | jq '[.[] | select(.fieldValueByName.name == "Done")] | length' 2>/dev/null)
      IN_PROGRESS=$(echo "$REPO_ITEMS" | jq '[.[] | select(.fieldValueByName.name == "In Progress")] | length' 2>/dev/null)
      TODO=$(echo "$REPO_ITEMS" | jq '[.[] | select(.fieldValueByName.name == "Todo")] | length' 2>/dev/null)

      TOTAL=${TOTAL:-0}
      DONE=${DONE:-0}
      IN_PROGRESS=${IN_PROGRESS:-0}
      TODO=${TODO:-0}

      # プロジェクト状態マーカー
      if [ "$CLOSED" = "true" ]; then
        STATE_MARKER="[Closed]"
      else
        STATE_MARKER="[Open]"
      fi

      # サマリー行
      if [ "$TOTAL" -eq 0 ]; then
        echo "- ${TITLE} (#${NUMBER}) ${STATE_MARKER} — アイテムなし | ${LINK_STATUS}"
      elif [ "$TOTAL" -eq "$DONE" ] && [ "$TOTAL" -gt 0 ]; then
        echo "- ${TITLE} (#${NUMBER}) ${STATE_MARKER} — ${DONE}/${TOTAL} Done 全完了 | ${LINK_STATUS}"
      else
        echo "- ${TITLE} (#${NUMBER}) ${STATE_MARKER} — ${DONE}/${TOTAL} Done, ${IN_PROGRESS} In Progress, ${TODO} Todo | ${LINK_STATUS}"
      fi

      # ステータス異常の検出（データとして出力、判断は Claude に委ねる）
      # Open Issue なのに Status が Done
      OPEN_DONE=$(echo "$REPO_ITEMS" | jq -r '.[] | select(.content.state == "OPEN" and .fieldValueByName.name == "Done") | "  - Issue #\(.content.number) [Open] Status:Done"' 2>/dev/null)
      if [ -n "$OPEN_DONE" ]; then
        echo "$OPEN_DONE"
      fi

      # Closed Issue なのに Status が Done 以外
      CLOSED_NOT_DONE=$(echo "$REPO_ITEMS" | jq -r '.[] | select(.content.state == "CLOSED" and .fieldValueByName.name != "Done" and .fieldValueByName.name != null and .fieldValueByName.name != "") | "  - Issue #\(.content.number) [Closed] Status:\(.fieldValueByName.name)"' 2>/dev/null)
      if [ -n "$CLOSED_NOT_DONE" ]; then
        echo "$CLOSED_NOT_DONE"
      fi

    done
  else
    echo "（プロジェクトなし）"
  fi
  echo ""
fi

# === オープン Issue（15件に制限） ===
echo "### オープン Issue"
gh issue list --state open --limit 15 \
  --json number,title,labels,assignees \
  --jq '.[] | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title) @\(.assignees | map(.login) | join(","))"' 2>/dev/null
echo ""

# === 直近完了 ===
echo "### 最近完了 (5件)"
gh issue list --state closed --limit 5 \
  --json number,title,closedAt \
  --jq '.[] | "#\(.number) \(.title) (\(.closedAt[:10]))"' 2>/dev/null
echo ""

# === Git 状態 ===
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
echo ""

# === 整合性監査指示 ===
echo "### 整合性監査"
echo "上記のプロジェクト状態とワークフロールール（issue-lifecycle Skill）を照合し、"
echo "矛盾や不整合があれば issue-manager サブエージェントをバックグラウンド"
echo "（run_in_background: true）で起動して修復すること。"
echo "例: Closed プロジェクトに Open Issue、リポリンク切れ、ステータス乖離など。"
echo "矛盾がなければ監査スキップ。メインの作業はブロックしないこと。"
