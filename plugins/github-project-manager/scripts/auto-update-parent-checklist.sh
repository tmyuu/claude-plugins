#!/bin/bash
# PostToolUse Hook: 子 Issue close 成功後に親 Issue のチェックリストを自動更新
# 親 Issue の「- [ ] ... #N ...」を「- [x] ... #N ...」に変更する
# exit 0 常時（リマインド型）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Bash ツール以外は素通り
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# gh issue close 以外は素通り
if ! echo "$CMD" | grep -qE '^\s*gh\s+issue\s+close\b'; then
  exit 0
fi

# クローズした Issue 番号を取得
CHILD_NUM=$(echo "$CMD" | grep -oE 'gh\s+issue\s+close\s+([0-9]+)' | grep -oE '[0-9]+')
if [ -z "$CHILD_NUM" ]; then
  exit 0
fi

# リポジトリ情報
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
  exit 0
fi
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

# 親 Issue を Sub-issues API で検索
PARENT_INFO=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        parentIssue {
          number
          body
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO_NAME" -F number="$CHILD_NUM" 2>/dev/null)

PARENT_NUM=$(echo "$PARENT_INFO" | jq -r '.data.repository.issue.parentIssue.number // ""' 2>/dev/null)
PARENT_BODY=$(echo "$PARENT_INFO" | jq -r '.data.repository.issue.parentIssue.body // ""' 2>/dev/null)

if [ -z "$PARENT_NUM" ] || [ -z "$PARENT_BODY" ]; then
  # Sub-issues API で親が見つからない場合、Issue 本文の "Parent: #N" パターンもフォールバック検索
  CHILD_BODY=$(gh issue view "$CHILD_NUM" --json body --jq '.body' 2>/dev/null)
  PARENT_NUM=$(echo "$CHILD_BODY" | grep -oE 'Parent:\s*#[0-9]+' | grep -oE '[0-9]+' | head -1)

  if [ -z "$PARENT_NUM" ]; then
    exit 0
  fi

  PARENT_BODY=$(gh issue view "$PARENT_NUM" --json body --jq '.body' 2>/dev/null)
  if [ -z "$PARENT_BODY" ]; then
    exit 0
  fi
fi

# 親 Issue のチェックリストに子 Issue (#N) が含まれているか確認
if ! echo "$PARENT_BODY" | grep -qE "- \[ \].*#${CHILD_NUM}\b"; then
  # 未チェック項目に子 Issue の参照がない場合はスキップ
  exit 0
fi

# チェックリストを更新: - [ ] ... #N ... → - [x] ... #N ...
UPDATED_BODY=$(echo "$PARENT_BODY" | sed -E "s/^(\s*)- \[ \](.*#${CHILD_NUM}\b)/\1- [x]\2/g")

# 親 Issue を更新
gh issue edit "$PARENT_NUM" --body "$UPDATED_BODY" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "親 Issue #${PARENT_NUM} のチェックリストを更新しました（子 Issue #${CHILD_NUM} を完了）"

  # 残りの未チェック項目を確認
  REMAINING=$(echo "$UPDATED_BODY" | grep -cE '^\s*- \[ \]' 2>/dev/null || echo "0")
  if [ "$REMAINING" = "0" ]; then
    echo "親 Issue #${PARENT_NUM} の全チェックリストが完了しました。クローズを検討してください。"
  else
    echo "親 Issue #${PARENT_NUM} の残り未完了項目: ${REMAINING} 件"
  fi
fi

exit 0
