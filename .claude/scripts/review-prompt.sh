#!/bin/bash
# UserPromptSubmit Hook: ユーザー指示受付時に Issue 状態をレビューし行動指針を注入
# Claude が Issue を立てずにコーディングを始める問題を防止する
# ステータス遷移は check-issue-context.sh (Edit/Write 前) に集約
# exit 0 常時（コンテキスト注入型）

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -z "$BRANCH" ]; then
  exit 0
fi

# --- 現在のブランチから Issue 番号を抽出 ---
BRANCH_ISSUE=$(echo "$BRANCH" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | head -1)

# --- オープン Issue のリストを取得（軽量） ---
OPEN_ISSUES=$(gh issue list --limit 15 --state open --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null)

# --- 状態に応じたガイダンスを出力 ---
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  # main ブランチ: Issue 未確定の可能性が高い
  cat <<GUIDANCE
## ワークフローリマインド

現在 **${BRANCH}** ブランチにいます。コーディングに着手する前に、以下を確認してください:

1. **この指示に対応する既存 Issue があるか？** 下記オープン Issue を確認
2. **なければ /new-issue で Issue を作成** してから作業開始
3. **Issue 確定後にブランチを作成**: \`feature/#N-description\` 形式

### オープン Issue
${OPEN_ISSUES:-（なし）}

**重要: main ブランチ上でのソースコード編集はブロックされます。必ず Issue を確定し、feature ブランチを作成してから着手してください。**
GUIDANCE
elif [ -n "$BRANCH_ISSUE" ]; then
  # feature ブランチ: Issue 確定済み、チェックリスト状態を表示
  ISSUE_BODY=$(gh issue view "$BRANCH_ISSUE" --json body,title --jq '.title + "\n" + .body' 2>/dev/null)
  UNCHECKED=$(echo "$ISSUE_BODY" | grep -cE '^\s*- \[ \]' 2>/dev/null || echo "0")
  CHECKED=$(echo "$ISSUE_BODY" | grep -cE '^\s*- \[x\]' 2>/dev/null || echo "0")
  ISSUE_TITLE=$(echo "$ISSUE_BODY" | head -1)
  UNCHECKED_ITEMS=$(echo "$ISSUE_BODY" | grep -E '^\s*- \[ \]' 2>/dev/null)

  echo "## ワークフローリマインド"
  echo ""
  echo "対応 Issue: **#${BRANCH_ISSUE}** ${ISSUE_TITLE}"
  echo "${CHECKED} 完了 / ${UNCHECKED} 残り"
  echo ""
  if [ -n "$UNCHECKED_ITEMS" ] && [ "$UNCHECKED" -gt 0 ]; then
    echo "未完了:"
    echo "$UNCHECKED_ITEMS"
    echo ""
    echo "完了した項目があれば **/update-issue** でチェックリストを更新すること。"
  fi
  echo ""
  echo "作業中の注意:"
  echo "- コミットメッセージに **#${BRANCH_ISSUE}** を含める"
  echo "- PR 作成時は **Closes #${BRANCH_ISSUE}** を記載"
else
  # feature ブランチだが Issue 番号なし
  cat <<GUIDANCE
## ワークフローリマインド

現在 **${BRANCH}** ブランチにいますが、Issue 番号が含まれていません。
対応する Issue を確認し、必要ならブランチ名を修正してください。

### オープン Issue
${OPEN_ISSUES:-（なし）}
GUIDANCE
fi

exit 0
