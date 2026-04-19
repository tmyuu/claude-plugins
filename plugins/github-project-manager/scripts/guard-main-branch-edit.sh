#!/bin/bash
# PreToolUse (Edit/Write): main ブランチ上でのソースコード編集をブロック
# 設定ファイル・.claude/ 配下・ドキュメントは例外で許可

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | read_tool_name)

case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | read_tool_file_path)

# .claude/ 配下は常に許可（Hook 開発を妨げない）
echo "$FILE_PATH" | grep -qE '(^|/)\.claude/' && exit 0

# 設定・ドキュメント系は許可
BASENAME=$(basename "$FILE_PATH" 2>/dev/null)
case "$BASENAME" in
  .gitignore|.eslintrc*|.prettier*|*.config.*|*.json|*.toml|*.yaml|*.yml|*.md) exit 0 ;;
esac

BRANCH=$(get_current_branch)
[ -z "$BRANCH" ] && exit 0

# main/master 以外は素通り
case "$BRANCH" in
  main|master) ;;
  *) exit 0 ;;
esac

OPEN_ISSUES=$(gh issue list --limit 10 --state open --json number,title --jq '.[] | "  #\(.number) \(.title)"' 2>/dev/null)

cat >&2 <<FEEDBACK
main ブランチ上でのソースコード編集はワークフロー違反です。

手順:
1. この作業に対応する Issue を確認（既存 or /new-issue で新規作成）
2. /start #N で作業開始（ブランチ作成 + Status In Progress を一発で実行）
   または手動で git checkout -b feature/#N-description

オープン Issue:
${OPEN_ISSUES:-  （なし — /new-issue で作成してください）}
FEEDBACK
exit 2
