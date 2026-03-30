#!/bin/bash
# PreToolUse Hook (Edit/Write): Issue 未確定状態でのソースコード編集をブロック
# main ブランチ上での編集 → Issue を確定しブランチを作成するよう促す
# feature ブランチ上での編集 → 素通り
# exit 0 = 続行, exit 2 = ブロック

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Edit / Write 以外は素通り
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

# 編集対象ファイルを取得
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# .claude/ 配下の設定ファイルは常に許可（Hook自体の開発を妨げない）
if echo "$FILE_PATH" | grep -qE '(^|/)\.claude/'; then
  exit 0
fi

# 設定ファイル系は許可（.gitignore, package.json 等）
BASENAME=$(basename "$FILE_PATH" 2>/dev/null)
case "$BASENAME" in
  .gitignore|.eslintrc*|.prettier*|*.config.*|*.json|*.toml|*.yaml|*.yml|*.md)
    exit 0
    ;;
esac

# 現在のブランチを確認
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -z "$BRANCH" ]; then
  exit 0
fi

# main/master 以外のブランチなら素通り（Issue ブランチで作業中とみなす）
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
  exit 0
fi

# main ブランチでソースコード編集 → ブロック
OPEN_ISSUES=$(gh issue list --limit 10 --state open --json number,title --jq '.[] | "  #\(.number) \(.title)"' 2>/dev/null)

cat >&2 <<FEEDBACK
main ブランチ上でのソースコード編集はワークフロー違反です。

手順:
1. この作業に対応する Issue を確認（既存 or /new-issue で新規作成）
2. feature ブランチを作成: git checkout -b feature/#N-description
3. ブランチ上でコーディングを開始

オープン Issue:
${OPEN_ISSUES:-  （なし — /new-issue で作成してください）}
FEEDBACK
exit 2
