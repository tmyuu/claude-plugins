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

# === プロジェクト（1回の GraphQL で全件取得: Open / Closed 両方） ===
if [ -n "$OWNER" ]; then
  echo "### プロジェクト"

  # 全プロジェクトの詳細を1回のクエリで取得（org → user fallback）
  # items + repositories を含めることで N+1 問題を回避
  PROJECT_QUERY='
    {
      projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes {
          title number id closed
          repositories(first: 50) {
            nodes { nameWithOwner }
          }
          items(first: 100) {
            nodes {
              fieldValueByName(name: "Status") {
                ... on ProjectV2ItemFieldSingleSelectValue { name }
              }
              content {
                ... on Issue {
                  number state
                  repository { nameWithOwner }
                }
              }
            }
          }
        }
      }
    }'

  PROJECTS_RAW=$(gh api graphql -f query="{
    organization(login: \"$OWNER\") $PROJECT_QUERY
  }" 2>/dev/null)
  PROJECTS_JSON=$(echo "$PROJECTS_RAW" | jq '.data.organization.projectsV2.nodes // empty' 2>/dev/null)

  if [ -z "$PROJECTS_JSON" ] || [ "$PROJECTS_JSON" = "null" ]; then
    PROJECTS_RAW=$(gh api graphql -f query="{
      viewer $PROJECT_QUERY
    }" 2>/dev/null)
    PROJECTS_JSON=$(echo "$PROJECTS_RAW" | jq '.data.viewer.projectsV2.nodes // []' 2>/dev/null)
  fi

  if [ -n "$PROJECTS_JSON" ] && [ "$PROJECTS_JSON" != "null" ] && [ "$PROJECTS_JSON" != "[]" ]; then
    echo "$PROJECTS_JSON" | jq -r --arg repo "$REPO" '
      .[] |
      # リポリンク判定
      (if (.repositories.nodes // [] | map(select(.nameWithOwner == $repo)) | length) > 0 then "✓" else "✗" end) as $link |
      # このリポジトリのアイテムのみ
      ([.items.nodes[] | select(.content.repository.nameWithOwner == $repo)]) as $items |
      ($items | length) as $total |
      ([$items[] | select(.fieldValueByName.name == "Done")] | length) as $done |
      ([$items[] | select(.fieldValueByName.name == "In Progress")] | length) as $in_progress |
      ([$items[] | select(.fieldValueByName.name == "Todo")] | length) as $todo |
      (if .closed then "[Closed]" else "[Open]" end) as $state |
      # サマリー行
      (if $total == 0 then
        "- \(.title) (#\(.number)) \($state) — アイテムなし | リポリンク:\($link)"
      elif $total == $done and $total > 0 then
        "- \(.title) (#\(.number)) \($state) — \($done)/\($total) Done 全完了 | リポリンク:\($link)"
      else
        "- \(.title) (#\(.number)) \($state) — \($done)/\($total) Done, \($in_progress) In Progress, \($todo) Todo | リポリンク:\($link)"
      end),
      # ステータス異常: Open Issue なのに Done
      ($items[] | select(.content.state == "OPEN" and .fieldValueByName.name == "Done") | "  - Issue #\(.content.number) [Open] Status:Done"),
      # ステータス異常: Closed Issue なのに Done 以外
      ($items[] | select(.content.state == "CLOSED" and .fieldValueByName.name != "Done" and .fieldValueByName.name != null and .fieldValueByName.name != "") | "  - Issue #\(.content.number) [Closed] Status:\(.fieldValueByName.name)")
    ' 2>/dev/null
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
