#!/bin/bash
# UserPromptSubmit: ユーザー指示受付時に Issue 状態を注入して行動指針を示す
# - main/master: Issue を立ててからブランチを切る
# - feature/#N:  Issue #N の情報と「範囲外警告」を注入
# - feature/(#N なし): ブランチ名を整えるよう誘導

source "$(dirname "$0")/lib.sh"

BRANCH=$(get_current_branch)
[ -z "$BRANCH" ] && exit 0

BRANCH_ISSUE=$(echo "$BRANCH" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | head -1)

OPEN_ISSUES=$(gh issue list --limit 15 --state open --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null)

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  cat <<GUIDANCE
## ワークフローリマインド

現在 **${BRANCH}** ブランチにいます。コーディングに着手する前に、以下を確認してください:

1. **この指示に対応する既存 Issue があるか？** 下記オープン Issue を確認
2. **なければ /new-issue で Issue を作成** してから作業開始
3. **Issue 確定後に /start #N で作業開始**（ブランチ作成 + Status In Progress を一発で）

### オープン Issue
${OPEN_ISSUES:-（なし）}

**重要: main ブランチ上でのソースコード編集はブロックされます。必ず Issue を確定し、feature ブランチを作成してから着手してください。**
GUIDANCE
elif [ -n "$BRANCH_ISSUE" ]; then
  ISSUE_TITLE=$(get_issue_title "$BRANCH_ISSUE")
  ISSUE_BODY=$(get_issue_body "$BRANCH_ISSUE")
  UNCHECKED_ITEMS=$(unchecked_items_in_body "$ISSUE_BODY")
  UNCHECKED=$(echo "$ISSUE_BODY" | grep -cE '^\s*- \[ \]' 2>/dev/null || echo "0")
  CHECKED=$(echo "$ISSUE_BODY" | grep -cE '^\s*- \[x\]' 2>/dev/null || echo "0")

  cat <<GUIDANCE
## ワークフローリマインド

対応 Issue: **#${BRANCH_ISSUE}** ${ISSUE_TITLE}
${CHECKED} 完了 / ${UNCHECKED} 残り

GUIDANCE

  if [ -n "$UNCHECKED_ITEMS" ] && [ "$UNCHECKED" != "0" ]; then
    echo "未完了:"
    echo "$UNCHECKED_ITEMS"
    echo ""
    echo "完了した項目があれば **/update-issue** でチェックリストを更新すること。"
    echo ""
  fi

  cat <<GUIDANCE
**スコープ判断（重要）**:
- 今回の指示が上記 Issue #${BRANCH_ISSUE} の範囲内 → そのまま作業を続ける
- 範囲外 or 新しい関心事 → コーディング前に /new-issue で別 Issue を立てる
  - 親子関係がある場合は Sub-issues API で紐付け、親のチェックリストに追加
  - 判断に迷ったらユーザーに確認

作業中の注意:
- コミットメッセージに **#${BRANCH_ISSUE}** を含める
- PR 作成時は **Closes #${BRANCH_ISSUE}** を記載
- 完了したアクションアイテムは都度 /update-issue でチェック
GUIDANCE
else
  cat <<GUIDANCE
## ワークフローリマインド

現在 **${BRANCH}** ブランチにいますが、Issue 番号が含まれていません。
対応する Issue を確認し、必要なら /start #N で作業ブランチを作り直してください。

### オープン Issue
${OPEN_ISSUES:-（なし）}
GUIDANCE
fi

exit 0
