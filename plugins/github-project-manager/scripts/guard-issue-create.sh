#!/bin/bash
# PreToolUse: gh issue create に必須オプションが揃っていなければブロック
# さらに --label に Type 語（bug/task/feature/minutes/acceptance/バグ/機能）が
# 混入していたらブロックし、Issue Type での表現を誘導する。

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

is_first_line_cmd "$CMD" '^\s*gh\s+issue\s+create\b' || exit 0

ERRORS=""

# --- 必須オプション ---
if ! echo "$CMD" | grep -qE '\-\-label'; then
  ERRORS="${ERRORS}--label が指定されていません。フェーズラベル + 重要度ラベルを付与してください。\n  例: --label \"開発,重要度:中\"\n  有効なフェーズ: ヒアリング / 見積もり / 開発 / テスト / 納品\n  有効な重要度: 重要度:高 / 重要度:中 / 重要度:低\n\n"
else
  # --label の値を抽出（quoted → unquoted の順で試行）
  LABEL_VAL=$(echo "$CMD" | grep -oE '\-\-label[= ]"[^"]+"' | head -1 | sed -E 's/^--label[= ]"//; s/"$//')
  if [ -z "$LABEL_VAL" ]; then
    LABEL_VAL=$(echo "$CMD" | grep -oE "\-\-label[= ]'[^']+'" | head -1 | sed -E "s/^--label[= ]'//; s/'$//")
  fi
  if [ -z "$LABEL_VAL" ]; then
    LABEL_VAL=$(echo "$CMD" | grep -oE '\-\-label[= ][^ ]+' | head -1 | sed -E 's/^--label[= ]//')
  fi

  # カンマ区切りで各ラベルを Type 語判定
  TYPE_IN_LABEL=""
  OLD_IFS=$IFS
  IFS=','
  for label in $LABEL_VAL; do
    trimmed=$(echo "$label" | xargs)
    lower=$(echo "$trimmed" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
      bug|task|feature|minutes|acceptance)
        TYPE_IN_LABEL="$trimmed"
        break
        ;;
    esac
    case "$trimmed" in
      バグ|機能|タスク|議事録|検収)
        TYPE_IN_LABEL="$trimmed"
        break
        ;;
    esac
  done
  IFS=$OLD_IFS

  if [ -n "$TYPE_IN_LABEL" ]; then
    ERRORS="${ERRORS}--label に Type 語「${TYPE_IN_LABEL}」が混入しています。\n  Type（Task / Bug / Feature / Minutes / Acceptance）は **GitHub Issue Type** で表現します。\n  Label は 2 軸のみ:\n    - フェーズ: ヒアリング / 見積もり / 開発 / テスト / 納品\n    - 重要度: 重要度:高 / 重要度:中 / 重要度:低\n  対応:\n    1. --label から Type 語を外す（例: --label \"開発,重要度:中\"）\n    2. Issue 作成後に updateIssueIssueType mutation で Type を設定（org リポジトリのみ）\n\n"
  fi
fi

if ! echo "$CMD" | grep -qE '\-\-assignee'; then
  ERRORS="${ERRORS}--assignee が指定されていません。\n  gh api user --jq '.login' でユーザー名を取得し、--assignee に設定してください。\n\n"
fi

if ! echo "$CMD" | grep -qE '\-\-project'; then
  ERRORS="${ERRORS}--project が指定されていません。\n  SessionStart で注入された「プロジェクト」一覧から該当プロジェクトを指定してください。\n\n"
fi

if [ -n "$ERRORS" ]; then
  {
    echo "gh issue create に問題があります:"
    echo ""
    echo -e "$ERRORS"
    echo "※ 作成前に SessionStart で注入された「オープン Issue」一覧を確認し、"
    echo "  同じ目的の Issue が既にないか確認してください。"
  } >&2
  exit 2
fi

echo "✓ Issue 作成チェック通過。重複 Issue がないことを確認済みですか？"
exit 0
