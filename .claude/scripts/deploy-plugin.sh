#!/bin/bash
# プラグインを複数のリポジトリへ並列展開するスクリプト
# 使い方:
#   .claude/scripts/deploy-plugin.sh                    # 全ファイル全リポジトリ展開
#   .claude/scripts/deploy-plugin.sh <file1> <file2>    # 指定ファイルのみ展開
#   .claude/scripts/deploy-plugin.sh --list             # 展開先リポジトリ一覧を表示
#
# 展開先リポジトリは TARGET_REPOS で定義（必要に応じて編集）

SOURCE_DIR="$HOME/Documents/claude-plugins/.claude"
TARGET_REPOS=(
  "livspect"
  "sukunabikona"
  "kajitory"
  "pcnshibuya"
  "voiceos"
  "karuta"
)
DOCUMENTS_DIR="$HOME/Documents"

# --list オプション
if [ "$1" = "--list" ]; then
  echo "展開先リポジトリ:"
  for repo in "${TARGET_REPOS[@]}"; do
    echo "  - $repo"
  done
  exit 0
fi

# 展開対象ファイルを決定
if [ $# -eq 0 ]; then
  # 引数なし: .claude/ 配下の全ファイル（settings.local.json, CLAUDE.md を除く）
  FILES=$(cd "$SOURCE_DIR" && find . -type f \
    ! -name 'settings.local.json' \
    ! -name 'CLAUDE.md' \
    ! -path './*.log' \
    | sed 's|^\./||')
else
  # 引数ありの場合はそれをファイルパスとして使う（.claude/ からの相対パス）
  FILES="$*"
fi

if [ -z "$FILES" ]; then
  echo "⚠ 展開対象ファイルがありません"
  exit 1
fi

# 1 リポジトリへの展開ロジック（並列実行用関数）
deploy_to_repo() {
  local repo="$1"
  local target_base="$DOCUMENTS_DIR/$repo/.claude"

  if [ ! -d "$DOCUMENTS_DIR/$repo" ]; then
    echo "⚠ $repo: ディレクトリが存在しません"
    return 1
  fi

  local count=0
  for file in $FILES; do
    local src="$SOURCE_DIR/$file"
    local dst="$target_base/$file"
    if [ ! -f "$src" ]; then
      continue
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    count=$((count + 1))
  done

  # .sh ファイルに実行権限を付与
  find "$target_base/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null

  echo "✓ $repo: $count ファイル展開"
}

export -f deploy_to_repo
export SOURCE_DIR DOCUMENTS_DIR FILES

# 並列展開（xargs -P でリポジトリ数だけ並列実行）
printf '%s\n' "${TARGET_REPOS[@]}" | xargs -I {} -P "${#TARGET_REPOS[@]}" bash -c 'deploy_to_repo "$@"' _ {}

echo ""
echo "展開完了: ${#TARGET_REPOS[@]} リポジトリ"
