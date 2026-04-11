#!/bin/bash
# PostToolUse Hook: 子 Issue クローズ時に親の stage ラベル自動推進を提案
# 自動変更はしない。提案のみ（stdout で Claude に伝える）
# exit 0 常時（リマインド型）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# gh issue close のみ対象
FIRST_LINE=$(echo "$CMD" | head -1)
if ! echo "$FIRST_LINE" | grep -qE '^\s*gh\s+issue\s+close\b'; then
  exit 0
fi

ISSUE_NUM=$(echo "$CMD" | grep -oE 'gh\s+issue\s+close\s+([0-9]+)' | grep -oE '[0-9]+')
if [ -z "$ISSUE_NUM" ]; then
  exit 0
fi

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
  exit 0
fi
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

# クローズした Issue の親を取得（Sub-issues API）
PARENT_NUM=$(gh api "repos/$OWNER/$REPO_NAME/issues/$ISSUE_NUM" --jq '.parent.number // empty' 2>/dev/null)

if [ -z "$PARENT_NUM" ]; then
  exit 0
fi

# 親の現在の stage ラベルを取得
PARENT_LABELS=$(gh issue view "$PARENT_NUM" --json labels --jq '.labels[].name' 2>/dev/null)
CURRENT_STAGE=$(echo "$PARENT_LABELS" | grep '^stage:' | head -1)

if [ -z "$CURRENT_STAGE" ]; then
  exit 0
fi

# クローズした子 Issue のタイプラベルを取得
CHILD_LABELS=$(gh issue view "$ISSUE_NUM" --json labels --jq '.labels[].name' 2>/dev/null)
CHILD_TYPE=$(echo "$CHILD_LABELS" | grep '^type:' | head -1)

# stage 推進マップ: 子のタイプ × 親の現在 stage → 推奨 stage
SUGGEST=""
case "$CURRENT_STAGE" in
  "stage:lead")
    # リードから次へ: アポが取れたら appointment
    SUGGEST="stage:appointment"
    ;;
  "stage:appointment")
    # アポから次へ: 打ち合わせ実施で meeting
    if [ "$CHILD_TYPE" = "type:議事録" ] || [ "$CHILD_TYPE" = "type:meeting" ]; then
      SUGGEST="stage:meeting"
    fi
    ;;
  "stage:meeting")
    # 打ち合わせから次へ: 提案書関連タスク完了で proposal
    # ただし meeting フェーズは複数回の打ち合わせがあり得るので慎重に
    ;;
  "stage:proposal")
    # 提案から次へ: 自動推進しない（受注判定はユーザー判断）
    ;;
esac

if [ -n "$SUGGEST" ]; then
  echo ""
  echo "💡 営業パイプライン: 親 Issue #$PARENT_NUM の stage 更新を検討してください"
  echo "  現在: $CURRENT_STAGE → 推奨: $SUGGEST"
  echo "  更新する場合: gh issue edit $PARENT_NUM --remove-label \"$CURRENT_STAGE\" --add-label \"$SUGGEST\""
  echo "  ※ ユーザーに確認してから実行してください"
fi

exit 0
