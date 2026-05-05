#!/bin/bash
# PreToolUse: プロジェクト新規作成をブロック（既存プロジェクトへの紐付けが原則）
# 例外: /new-project コマンドは CLAUDE_NEW_PROJECT_ALLOW=1 を頭に付けて実行することで通過する

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

# /new-project からの明示的バイパス（コマンド先頭の env prefix を検出）
if echo "$CMD" | head -1 | grep -qE '^\s*CLAUDE_NEW_PROJECT_ALLOW=1\s'; then
  exit 0
fi

if is_first_line_cmd "$CMD" '^\s*gh\s+project\s+create\b'; then
  cat >&2 <<'FEEDBACK'
プロジェクトの新規作成はブロックされました。

原則:
- プロジェクトは既存のものに紐付けてください
- SessionStart で注入された「プロジェクト」一覧を確認してください

新規 Project が本当に必要な場合:
- /new-project コマンドを使用してください（作成 + リポリンクを一括で実行）
  例: /new-project 案件A 開発
- /new-project は内部で CLAUDE_NEW_PROJECT_ALLOW=1 を付けてこのガードをバイパスします
FEEDBACK
  exit 2
fi

if is_first_line_cmd "$CMD" 'createProjectV2'; then
  cat >&2 <<'FEEDBACK'
GraphQL によるプロジェクト新規作成はブロックされました。

原則:
- プロジェクトは既存のものに紐付けてください
- 新規 Project が必要なら /new-project コマンドを使用してください
FEEDBACK
  exit 2
fi

exit 0
