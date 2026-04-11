#!/bin/bash
# SessionStart Hook: 営業パイプラインの概況を Claude のコンテキストに注入
# github-project-manager の inject-project-state.sh と併用される
# stdout の内容が Claude のコンテキストに追加される

# 前提条件チェック
if ! command -v gh &>/dev/null || ! command -v jq &>/dev/null; then
  exit 0
fi
if ! gh auth status &>/dev/null 2>&1; then
  exit 0
fi

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
  exit 0
fi

# stage ラベルの存在チェック（営業リポジトリかどうか判定）
HAS_STAGE=$(gh label list --json name --jq '[.[] | select(.name | startswith("stage:"))] | length' 2>/dev/null)
if [ "$HAS_STAGE" = "0" ] || [ -z "$HAS_STAGE" ]; then
  exit 0
fi

echo "## 営業パイプライン概況（自動注入）"
echo ""

# === stage 別の案件一覧 ===
echo "### パイプライン"

STAGES="lead appointment meeting proposal deal lost"
TOTAL_OPEN=0

for STAGE in $STAGES; do
  ISSUES=$(gh issue list --state open --label "stage:$STAGE" \
    --json number,title,assignees,labels \
    --jq '.[] | "#\(.number) \(.title) @\(.assignees | map(.login) | join(",")) [\(.labels | map(.name) | select(startswith("priority:") or startswith("stage:")) | join(","))]"' 2>/dev/null)

  COUNT=$(echo "$ISSUES" | grep -c '^#' 2>/dev/null || echo "0")
  if [ "$COUNT" -gt 0 ]; then
    TOTAL_OPEN=$((TOTAL_OPEN + COUNT))
    echo "**$STAGE** ($COUNT件)"
    echo "$ISSUES" | head -10
    echo ""
  fi
done

if [ "$TOTAL_OPEN" -eq 0 ]; then
  echo "（オープンな案件なし）"
  echo ""
fi

# === 最近の失注・成約 ===
echo "### 最近クローズ (5件)"
gh issue list --state closed --label "stage:deal" --limit 3 \
  --json number,title,closedAt \
  --jq '.[] | "✓ #\(.number) \(.title) (\(.closedAt[:10]))"' 2>/dev/null

gh issue list --state closed --label "stage:lost" --limit 2 \
  --json number,title,closedAt \
  --jq '.[] | "✗ #\(.number) \(.title) (\(.closedAt[:10]))"' 2>/dev/null
echo ""

echo "### 営業アクション（直近の子 Issue）"
# stage ラベルを持たない（= 子 Issue）で最近更新されたもの
gh issue list --state open --limit 5 \
  --json number,title,assignees,labels \
  --jq '[.[] | select(.labels | map(.name) | any(startswith("stage:")) | not)] | .[:5] | .[] | "#\(.number) \(.title) @\(.assignees | map(.login) | join(","))"' 2>/dev/null
echo ""
