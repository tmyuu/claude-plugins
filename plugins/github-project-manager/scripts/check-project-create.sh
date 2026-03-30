#!/bin/bash
# PreToolUse Hook: プロジェクト新規作成をブロック
# プロジェクトは既存のものに紐付けるのが原則。
# 新規作成が必要な場合は Issue で提案し、ユーザー承認を得てから行う。
# exit 0 = 続行, exit 2 = ブロック

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

FIRST_LINE=$(echo "$CMD" | head -1)

# gh project create / createProjectV2 をブロック
if echo "$FIRST_LINE" | grep -qE '^\s*gh\s+project\s+create\b'; then
  cat >&2 <<FEEDBACK
プロジェクトの新規作成はブロックされました。

原則:
- プロジェクトは既存のものに紐付けてください
- SessionStart で注入された「プロジェクト」一覧を確認してください
- 新規プロジェクトが本当に必要な場合は、Issue を作成してユーザーに提案してください

既存プロジェクトに該当がない場合の手順:
1. /new-issue で「新規プロジェクト作成の提案」Issue を作成
2. ユーザーの承認を得てから作成
FEEDBACK
  exit 2
fi

# GraphQL の createProjectV2 mutation もブロック（先頭行のみ判定）
if echo "$FIRST_LINE" | grep -qE 'createProjectV2'; then
  cat >&2 <<FEEDBACK
GraphQL によるプロジェクト新規作成はブロックされました。

原則:
- プロジェクトは既存のものに紐付けてください
- 新規プロジェクトが必要な場合は Issue でユーザーに提案してください
FEEDBACK
  exit 2
fi

exit 0
