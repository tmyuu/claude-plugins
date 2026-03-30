#!/bin/bash
# PreToolUse Hook: gh issue close / gh pr merge 前に未完了チェックリストを検証
# exit 0 = 続行, exit 2 = ブロック（stderr が Claude にフィードバックされ自己修正を促す）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# --- gh issue close の検出 ---
if echo "$CMD" | grep -qE '^\s*gh\s+issue\s+close\b'; then
  # Issue 番号を取得
  ISSUE_NUM=$(echo "$CMD" | grep -oE 'gh\s+issue\s+close\s+([0-9]+)' | grep -oE '[0-9]+')
  if [ -z "$ISSUE_NUM" ]; then
    exit 0
  fi

  ISSUE_BODY=$(gh issue view "$ISSUE_NUM" --json body --jq '.body' 2>/dev/null)
  if [ -z "$ISSUE_BODY" ]; then
    exit 0
  fi

  UNCHECKED=$(echo "$ISSUE_BODY" | grep -E '^\s*- \[ \]' || true)
  if [ -n "$UNCHECKED" ]; then
    cat >&2 <<FEEDBACK
Issue #${ISSUE_NUM} に未完了のチェックリストがあります。クローズ前に確認してください。

未完了項目:
${UNCHECKED}

対応方法:
1. 各項目が本当に完了しているか確認
2. 完了していれば /update-issue で Issue のチェックリストを更新してからクローズ
3. 対応不要な項目があればユーザーに確認
FEEDBACK
    exit 2
  fi

  exit 0
fi

# --- gh pr merge の検出 ---
if echo "$CMD" | grep -qE '^\s*gh\s+pr\s+merge\b'; then
  # PR 番号を取得
  PR_NUM=$(echo "$CMD" | grep -oE 'gh\s+pr\s+merge\s+([0-9]+)' | grep -oE '[0-9]+')

  if [ -z "$PR_NUM" ]; then
    PR_NUM=$(gh pr view --json number --jq '.number' 2>/dev/null)
  fi

  if [ -z "$PR_NUM" ]; then
    exit 0
  fi

  # PR に紐づく Issue 番号を取得（Closes #N パターン）
  PR_BODY=$(gh pr view "$PR_NUM" --json body --jq '.body' 2>/dev/null)
  ISSUE_NUMS=$(echo "$PR_BODY" | grep -oiE '(closes?|fix(es)?|resolves?)\s+#[0-9]+' | grep -oE '[0-9]+')

  if [ -z "$ISSUE_NUMS" ]; then
    exit 0
  fi

  # 各 Issue の完了条件（チェックリスト）を検証
  UNCHECKED_ITEMS=""
  for ISSUE_NUM in $ISSUE_NUMS; do
    ISSUE_BODY=$(gh issue view "$ISSUE_NUM" --json body --jq '.body' 2>/dev/null)
    if [ -z "$ISSUE_BODY" ]; then
      continue
    fi

    UNCHECKED=$(echo "$ISSUE_BODY" | grep -E '^\s*- \[ \]' || true)
    if [ -n "$UNCHECKED" ]; then
      UNCHECKED_ITEMS="${UNCHECKED_ITEMS}
Issue #${ISSUE_NUM} の未完了項目:
${UNCHECKED}
"
    fi
  done

  if [ -n "$UNCHECKED_ITEMS" ]; then
    cat >&2 <<FEEDBACK
マージ前に Issue の完了条件を確認してください。
${UNCHECKED_ITEMS}
対応方法:
1. 各項目が本当に完了しているか確認
2. 完了していれば /update-issue で Issue のチェックリストを更新
3. 完了していなければ残作業を行うか、ユーザーに確認
FEEDBACK
    exit 2
  fi

  exit 0
fi

# その他のコマンドは素通り
exit 0
