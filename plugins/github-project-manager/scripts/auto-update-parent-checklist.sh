#!/bin/bash
# PostToolUse: 子 Issue がクローズされたら親 Issue のチェックリストを自動更新
# 検知する経路:
#   1. gh issue close N
#   2. gh pr merge [N]  → PR 本文の Closes #N を展開
# 親 Issue の「- [ ] ... #N ...」を「- [x] ... #N ...」に変更

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | read_tool_name)
[ "$TOOL_NAME" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | read_command)

# 対象の子 Issue 番号を収集
CHILD_NUMS=""
if is_first_line_cmd "$CMD" '^\s*gh\s+issue\s+close\b'; then
  CHILD_NUMS=$(echo "$CMD" | grep -oE 'gh\s+issue\s+close\s+([0-9]+)' | grep -oE '[0-9]+')
elif is_first_line_cmd "$CMD" '^\s*gh\s+pr\s+merge\b'; then
  PR_NUM=$(echo "$CMD" | grep -oE 'gh\s+pr\s+merge\s+([0-9]+)' | grep -oE '[0-9]+')
  [ -z "$PR_NUM" ] && PR_NUM=$(get_pr_number_current)
  if [ -n "$PR_NUM" ]; then
    PR_BODY=$(get_pr_body "$PR_NUM")
    CHILD_NUMS=$(extract_closing_refs "$PR_BODY")
  fi
fi

[ -z "$CHILD_NUMS" ] && exit 0

get_repo_info || exit 0

update_one_child() {
  local child_num="$1"

  # Sub-issues API で親を取得
  local parent_info parent_num parent_body
  parent_info=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) {
          parentIssue { number body }
        }
      }
    }
  ' -f owner="$OWNER" -f repo="$REPO_NAME" -F number="$child_num" 2>/dev/null)

  parent_num=$(echo "$parent_info" | jq -r '.data.repository.issue.parentIssue.number // ""')
  parent_body=$(echo "$parent_info" | jq -r '.data.repository.issue.parentIssue.body // ""')

  # フォールバック: 子本文の "Parent: #N"
  if [ -z "$parent_num" ] || [ -z "$parent_body" ]; then
    local child_body
    child_body=$(get_issue_body "$child_num")
    parent_num=$(echo "$child_body" | grep -oE 'Parent:\s*#[0-9]+' | grep -oE '[0-9]+' | head -1)
    [ -z "$parent_num" ] && return 0
    parent_body=$(get_issue_body "$parent_num")
    [ -z "$parent_body" ] && return 0
  fi

  # 親のチェックリストに該当子の参照が無ければ何もしない
  if ! echo "$parent_body" | grep -qE "- \[ \].*#${child_num}\b"; then
    return 0
  fi

  local updated_body
  updated_body=$(echo "$parent_body" | sed -E "s/^(\s*)- \[ \](.*#${child_num}\b)/\1- [x]\2/g")

  if gh issue edit "$parent_num" --body "$updated_body" >/dev/null 2>&1; then
    echo "親 Issue #${parent_num} のチェックリストを更新しました（子 Issue #${child_num} を完了）"
    local remaining
    remaining=$(echo "$updated_body" | grep -cE '^\s*- \[ \]' 2>/dev/null || echo "0")
    if [ "$remaining" = "0" ]; then
      echo "親 Issue #${parent_num} の全チェックリストが完了しました。クローズを検討してください。"
    else
      echo "親 Issue #${parent_num} の残り未完了項目: ${remaining} 件"
    fi
  fi
}

for num in $CHILD_NUMS; do
  update_one_child "$num"
done

exit 0
