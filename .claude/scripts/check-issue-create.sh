#!/bin/bash
# PreToolUse Hook: gh issue create に --label と --assignee があるかチェック
# exit 0 = 続行, exit 2 = ブロック（stderr が Claude にフィードバックされ自己修正を促す）

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# gh issue create 以外は素通り（コミットメッセージ内の文字列に誤反応しないよう先頭行のみ判定）
FIRST_LINE=$(echo "$CMD" | head -1)
if ! echo "$FIRST_LINE" | grep -qE '^\s*gh\s+issue\s+create\b'; then
  exit 0
fi

ERRORS=""

# --label チェック
if ! echo "$CMD" | grep -qE '\-\-label'; then
  ERRORS="${ERRORS}--label が指定されていません。フェーズラベル + 重要度ラベルを付与してください。\n  例: --label \"開発,重要度:中\"\n  有効なフェーズ: ヒアリング / 見積もり / 開発 / テスト / 納品\n  有効な重要度: 重要度:高 / 重要度:中 / 重要度:低\n\n"
fi

# --assignee チェック
if ! echo "$CMD" | grep -qE '\-\-assignee'; then
  ERRORS="${ERRORS}--assignee が指定されていません。\n  gh api user --jq '.login' でユーザー名を取得し、--assignee に設定してください。\n\n"
fi

# --project チェック
if ! echo "$CMD" | grep -qE '\-\-project'; then
  ERRORS="${ERRORS}--project が指定されていません。\n  SessionStart で注入された「プロジェクト」一覧から該当プロジェクトを指定してください。\n\n"
fi

if [ -n "$ERRORS" ]; then
  echo "gh issue create に必須オプションが不足しています:" >&2
  echo "" >&2
  echo -e "$ERRORS" >&2
  echo "※ 作成前に SessionStart で注入された「オープン Issue」一覧を確認し、" >&2
  echo "  同じ目的の Issue が既にないか確認してください。" >&2
  exit 2
fi

# --project の値がリポジトリにリンクされたプロジェクトか検証
PROJECT_NAME=$(echo "$CMD" | grep -oE '\-\-project\s+"[^"]+"' | sed 's/--project[[:space:]]*//' | tr -d '"')
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(echo "$CMD" | grep -oE "\-\-project\s+'[^']+'" | sed "s/--project[[:space:]]*//" | tr -d "'")
fi
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(echo "$CMD" | grep -oE '\-\-project\s+[^ ]+' | sed 's/--project[[:space:]]*//')
fi

if [ -n "$PROJECT_NAME" ]; then
  REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
  OWNER=$(echo "$REPO" | cut -d'/' -f1)

  # プロジェクト一覧 + リポリンクを取得（org → user fallback）
  PROJECTS_RAW=$(gh api graphql -f query="{
    organization(login: \"$OWNER\") {
      projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes {
          title
          closed
          repositories(first: 50) { nodes { nameWithOwner } }
        }
      }
    }
  }" 2>/dev/null)
  PROJECTS_JSON=$(echo "$PROJECTS_RAW" | jq '.data.organization.projectsV2.nodes // empty' 2>/dev/null)

  if [ -z "$PROJECTS_JSON" ] || [ "$PROJECTS_JSON" = "null" ]; then
    PROJECTS_RAW=$(gh api graphql -f query="{
      viewer {
        projectsV2(first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes {
            title
            closed
            repositories(first: 50) { nodes { nameWithOwner } }
          }
        }
      }
    }" 2>/dev/null)
    PROJECTS_JSON=$(echo "$PROJECTS_RAW" | jq '.data.viewer.projectsV2.nodes // []' 2>/dev/null)
  fi

  # 指定プロジェクトがリポジトリにリンクされているか確認
  LINKED=$(echo "$PROJECTS_JSON" | jq -r --arg name "$PROJECT_NAME" --arg repo "$REPO" \
    '.[] | select(.title == $name and .closed == false) | .repositories.nodes[]? | select(.nameWithOwner == $repo) | .nameWithOwner' 2>/dev/null)

  if [ -z "$LINKED" ]; then
    # リポジトリにリンクされたプロジェクト一覧を取得
    LINKED_PROJECTS=$(echo "$PROJECTS_JSON" | jq -r --arg repo "$REPO" \
      '.[] | select(.closed == false) | select(.repositories.nodes[]?.nameWithOwner == $repo) | "  - \(.title)"' 2>/dev/null)

    cat >&2 <<FEEDBACK
プロジェクト「${PROJECT_NAME}」はこのリポジトリにリンクされていません。

リポリンク済みのプロジェクト:
${LINKED_PROJECTS:-  （なし — ユーザーにどのプロジェクトを使うか確認してください）}

対応方法:
1. 上記のリンク済みプロジェクトから選んでください
2. リンクされていないプロジェクトを使う場合は linkProjectV2ToRepository で先にリンク
3. 該当するプロジェクトがない場合はユーザーに確認
FEEDBACK
    exit 2
  fi
fi

# 通過する場合もリマインド（stdout で注入）
echo "✓ Issue 作成チェック通過。重複 Issue がないことを確認済みですか？"

exit 0
