#!/bin/bash
# PostToolUse: Issue のプロジェクトステータスを作業状態に合わせて自動遷移
#   - git commit 成功    → コミットメッセージ中の Issue を Todo → In Progress
#   - gh issue close     → 対象 Issue を Done
#   - gh pr merge        → PR 本文の Closes #N（無ければブランチ由来）を Done

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | read_tool_name)
[ "$TOOL_NAME" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | read_command)

# --- 遷移対象の決定 ---
TARGET=""     # "In Progress" or "Done"
FROM=""       # 任意: 指定ステータスからの遷移のみ許可
ISSUE_NUMS=""

if is_first_line_cmd "$CMD" '^\s*git\s+commit\b'; then
  echo "$CMD" | grep -qF -- '--amend' && exit 0
  TARGET="In Progress"
  FROM="Todo"
  ISSUE_NUMS=$(extract_issue_nums "$CMD")
elif is_first_line_cmd "$CMD" '^\s*gh\s+issue\s+close\b'; then
  TARGET="Done"
  ISSUE_NUMS=$(echo "$CMD" | grep -oE 'gh\s+issue\s+close\s+([0-9]+)' | grep -oE '[0-9]+')
elif is_first_line_cmd "$CMD" '^\s*gh\s+pr\s+merge\b'; then
  TARGET="Done"
  PR_NUM=$(echo "$CMD" | grep -oE 'gh\s+pr\s+merge\s+([0-9]+)' | grep -oE '[0-9]+')
  [ -z "$PR_NUM" ] && PR_NUM=$(get_pr_number_current)
  if [ -n "$PR_NUM" ]; then
    PR_BODY=$(get_pr_body "$PR_NUM")
    ISSUE_NUMS=$(extract_closing_refs "$PR_BODY")
    if [ -z "$ISSUE_NUMS" ]; then
      ISSUE_NUMS=$(gh pr view "$PR_NUM" --json headRefName --jq '.headRefName' 2>/dev/null | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | head -1)
    fi
  fi
fi

if [ -z "$TARGET" ] || [ -z "$ISSUE_NUMS" ]; then
  exit 0
fi

UPDATED=""
for num in $ISSUE_NUMS; do
  if transition_issue_status "$num" "$TARGET" "$FROM"; then
    UPDATED="${UPDATED} #${num}"
  fi
done

if [ -n "$UPDATED" ]; then
  echo "Issue ステータスを ${TARGET} に更新しました:${UPDATED}"
fi

exit 0
