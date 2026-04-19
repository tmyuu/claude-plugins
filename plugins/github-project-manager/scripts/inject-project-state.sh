#!/bin/bash
# SessionStart: プロジェクト状態を Claude のコンテキストに包括的に注入
# Claude が整合性を判断し、矛盾があればバックグラウンドで修復できるよう全状態を出力する
# stdout の内容が Claude のコンテキストに追加される

source "$(dirname "$0")/lib.sh"

has_jq || { echo "⚠ jq が見つかりません"; exit 0; }
has_gh || { echo "⚠ gh CLI が未認証または未インストールです"; exit 0; }

echo "## プロジェクト状態（自動注入）"
echo ""

if ! get_repo_info; then
  echo "⚠ リポジトリ情報を取得できませんでした"
  exit 0
fi

echo "リポジトリ: $REPO"
echo ""

# === プロジェクト（1回の GraphQL で全件取得: Open / Closed 両方） ===
echo "### プロジェクト"

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
    (if (.repositories.nodes // [] | map(select(.nameWithOwner == $repo)) | length) > 0 then "✓" else "✗" end) as $link |
    ([.items.nodes[] | select(.content.repository.nameWithOwner == $repo)]) as $items |
    ($items | length) as $total |
    ([$items[] | select(.fieldValueByName.name == "Done")] | length) as $done |
    ([$items[] | select(.fieldValueByName.name == "In Progress")] | length) as $in_progress |
    ([$items[] | select(.fieldValueByName.name == "Todo")] | length) as $todo |
    (if .closed then "[Closed]" else "[Open]" end) as $state |
    (if $total == 0 then
      "- \(.title) (#\(.number)) \($state) — アイテムなし | リポリンク:\($link)"
    elif $total == $done and $total > 0 then
      "- \(.title) (#\(.number)) \($state) — \($done)/\($total) Done 全完了 | リポリンク:\($link)"
    else
      "- \(.title) (#\(.number)) \($state) — \($done)/\($total) Done, \($in_progress) In Progress, \($todo) Todo | リポリンク:\($link)"
    end),
    ($items[] | select(.content.state == "OPEN" and .fieldValueByName.name == "Done") | "  - Issue #\(.content.number) [Open] Status:Done"),
    ($items[] | select(.content.state == "CLOSED" and .fieldValueByName.name != "Done" and .fieldValueByName.name != null and .fieldValueByName.name != "") | "  - Issue #\(.content.number) [Closed] Status:\(.fieldValueByName.name)")
  ' 2>/dev/null
else
  echo "（プロジェクトなし）"
fi
echo ""

# === オープン Issue（15件に制限） ===
echo "### オープン Issue"
gh issue list --state open --limit 15 \
  --json number,title,labels,assignees \
  --jq '.[] | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title) @\(.assignees | map(.login) | join(","))"' 2>/dev/null
echo ""

# === 直近完了 + チェックリスト未完了×Closed の異常検知 ===
echo "### 最近完了 (5件)"
RECENT_CLOSED=$(gh issue list --state closed --limit 5 \
  --json number,title,closedAt,body 2>/dev/null)

if [ -n "$RECENT_CLOSED" ]; then
  echo "$RECENT_CLOSED" | jq -r '.[] | "#\(.number) \(.title) (\(.closedAt[:10]))"'

  # 異常検知: 本文に未完了チェック `- [ ]` を含む Closed Issue を列挙
  ANOMALIES=$(echo "$RECENT_CLOSED" | jq -r '
    .[] | select(.body | test("(?m)^\\s*- \\[ \\]")) |
    "- #\(.number) \(.title) — 未完了チェックあり"
  ' 2>/dev/null)

  if [ -n "$ANOMALIES" ]; then
    echo ""
    echo "**⚠ 異常: チェックリスト未完了で Closed の Issue**"
    echo "$ANOMALIES"
  fi
fi
echo ""

# === Git 状態 ===
echo "### Git"
echo "branch: $(get_current_branch)"
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
cat <<'AUDIT'
### 整合性監査
上記のプロジェクト状態とワークフロールール（issue-lifecycle Skill）を照合し、
矛盾や不整合があれば issue-manager サブエージェントをバックグラウンド
（run_in_background: true）で起動して修復すること。

代表的な異常パターン:
- Closed プロジェクトに Open Issue が残っている
- リポリンク切れ（リポリンク:✗）
- Open Issue なのに Status:Done / Closed Issue なのに Status:Todo 等のステータス乖離
- **チェックリスト未完了で Closed**（= 作業が終わっていないのに閉じている）
  → reopen してチェックを埋めるか、ユーザーに「意図的に閉じたか」を確認

矛盾がなければ監査スキップ。メインの作業はブロックしないこと。
AUDIT
