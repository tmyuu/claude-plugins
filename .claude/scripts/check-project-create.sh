#!/bin/bash
# PreToolUse Hook: プロジェクト新規作成をブロック
# Webhook でリポジトリ紐付けを検知できないため、Claude からの作成は禁止。
# プロジェクトは人間が GitHub UI で作成し、リポジトリにリンクする。
# exit 0 = 続行, exit 2 = ブロック

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

FIRST_LINE=$(echo "$CMD" | head -1)

# gh project create をブロック
if echo "$FIRST_LINE" | grep -qE '^\s*gh\s+project\s+create\b'; then
  cat >&2 <<FEEDBACK
プロジェクトの新規作成はブロックされました。

理由: プロジェクト作成→リポジトリ紐付けが Webhook で検知できないため、
Claude からのプロジェクト作成は禁止しています。

プロジェクトはユーザーが GitHub UI で作成してください。
既存プロジェクトは SessionStart で注入された一覧を確認してください。
FEEDBACK
  exit 2
fi

# GraphQL の createProjectV2 mutation もブロック
if echo "$FIRST_LINE" | grep -qE 'createProjectV2'; then
  cat >&2 <<FEEDBACK
GraphQL によるプロジェクト新規作成はブロックされました。
プロジェクトはユーザーが GitHub UI で作成してください。
FEEDBACK
  exit 2
fi

exit 0
