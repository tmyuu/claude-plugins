#!/bin/bash
# PreToolUse: プロジェクト新規作成をブロック（既存プロジェクトへの紐付けが原則）

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

if is_first_line_cmd "$CMD" '^\s*gh\s+project\s+create\b'; then
  cat >&2 <<'FEEDBACK'
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

if is_first_line_cmd "$CMD" 'createProjectV2'; then
  cat >&2 <<'FEEDBACK'
GraphQL によるプロジェクト新規作成はブロックされました。

原則:
- プロジェクトは既存のものに紐付けてください
- 新規プロジェクトが必要な場合は Issue でユーザーに提案してください
FEEDBACK
  exit 2
fi

exit 0
