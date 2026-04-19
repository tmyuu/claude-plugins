#!/bin/bash
# PreToolUse: Issue クローズ前に未完了チェックリストを検証
# 検知する経路:
#   1. gh issue close N
#   2. gh issue edit N --state closed
#   3. gh pr merge [N]         （PR 本文の Closes #N、無ければブランチから推測）
#   4. gh api graphql ... closeIssue / updateIssue { state: CLOSED }  → ブロック+誘導

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

# --- 未完了 Issue を列挙して失敗時メッセージを出す共通処理 ---
# 引数: $1..$N = Issue 番号
# 成功: 0（未完了なし）, 失敗: 1（未完了あり）
report_unchecked_or_pass() {
  local unchecked_out="" any_unchecked=0
  for num in "$@"; do
    local body unchecked
    body=$(get_issue_body "$num")
    [ -z "$body" ] && continue
    unchecked=$(unchecked_items_in_body "$body")
    if [ -n "$unchecked" ]; then
      any_unchecked=1
      unchecked_out="${unchecked_out}
Issue #${num} の未完了項目:
${unchecked}
"
    fi
  done

  if [ $any_unchecked -eq 1 ]; then
    cat >&2 <<FEEDBACK
クローズ前に Issue の完了条件を確認してください。
${unchecked_out}
対応方法:
1. 各項目が本当に完了しているか確認
2. 完了していれば /update-issue で Issue のチェックリストを更新してからクローズ
3. 対応不要な項目があればユーザーに確認
FEEDBACK
    return 1
  fi
  return 0
}

# --- 1. gh issue close N ---
if is_first_line_cmd "$CMD" '^\s*gh\s+issue\s+close\b'; then
  ISSUE_NUM=$(echo "$CMD" | grep -oE 'gh\s+issue\s+close\s+([0-9]+)' | grep -oE '[0-9]+')
  [ -z "$ISSUE_NUM" ] && exit 0
  report_unchecked_or_pass "$ISSUE_NUM" || exit 2
  exit 0
fi

# --- 2. gh issue edit N --state closed ---
if is_first_line_cmd "$CMD" '^\s*gh\s+issue\s+edit\b'; then
  if echo "$CMD" | grep -qE '\-\-state\s+closed\b'; then
    ISSUE_NUM=$(echo "$CMD" | grep -oE 'gh\s+issue\s+edit\s+([0-9]+)' | grep -oE '[0-9]+')
    [ -z "$ISSUE_NUM" ] && exit 0
    report_unchecked_or_pass "$ISSUE_NUM" || exit 2
  fi
  exit 0
fi

# --- 3. gh pr merge ---
if is_first_line_cmd "$CMD" '^\s*gh\s+pr\s+merge\b'; then
  PR_NUM=$(echo "$CMD" | grep -oE 'gh\s+pr\s+merge\s+([0-9]+)' | grep -oE '[0-9]+')
  [ -z "$PR_NUM" ] && PR_NUM=$(get_pr_number_current)
  [ -z "$PR_NUM" ] && exit 0

  # PR 本文の Closes #N、無ければブランチ名から推測
  PR_BODY=$(get_pr_body "$PR_NUM")
  ISSUE_NUMS=$(extract_closing_refs "$PR_BODY")

  if [ -z "$ISSUE_NUMS" ]; then
    BRANCH_ISSUE=$(gh pr view "$PR_NUM" --json headRefName --jq '.headRefName' 2>/dev/null | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | head -1)
    if [ -n "$BRANCH_ISSUE" ]; then
      ISSUE_NUMS="$BRANCH_ISSUE"
      {
        echo "⚠ PR #${PR_NUM} 本文に Closes #N が未記載です。"
        echo "  ブランチ名から Issue #${BRANCH_ISSUE} を推測して検証します。"
        echo "  → マージ前に PR 本文に 'Closes #${BRANCH_ISSUE}' を追加することを推奨。"
      } >&2
    fi
  fi

  [ -z "$ISSUE_NUMS" ] && exit 0
  # shellcheck disable=SC2086
  report_unchecked_or_pass $ISSUE_NUMS || exit 2
  exit 0
fi

# --- 4. gh api graphql による closeIssue / updateIssue{state:CLOSED} ---
if is_first_line_cmd "$CMD" '^\s*gh\s+api\s+graphql\b'; then
  if echo "$CMD" | grep -qE 'closeIssue\b'; then
    cat >&2 <<'FEEDBACK'
gh api graphql による closeIssue の実行はブロックされました。

理由: GraphQL 経由だと未完了チェックリストの検証を回避してしまいます。

対応方法:
- `gh issue close N` を使ってください（未完了チェックがかかります）
- どうしても GraphQL で閉じる必要がある場合はユーザーに確認してください
FEEDBACK
    exit 2
  fi
  if echo "$CMD" | grep -qE 'updateIssue\b' && echo "$CMD" | grep -qE 'state:\s*CLOSED'; then
    cat >&2 <<'FEEDBACK'
gh api graphql による updateIssue { state: CLOSED } の実行はブロックされました。

理由: GraphQL 経由だと未完了チェックリストの検証を回避してしまいます。

対応方法:
- `gh issue close N` を使ってください（未完了チェックがかかります）
FEEDBACK
    exit 2
  fi
fi

exit 0
