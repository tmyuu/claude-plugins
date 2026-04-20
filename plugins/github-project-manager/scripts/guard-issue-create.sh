#!/bin/bash
# PreToolUse: gh issue create の必須オプション・Label 規則を検証
#   - --assignee / --project 必須
#   - --label 必須。かつ taxonomy.json に沿って
#       * Type 語（bug/task/feature/minutes/acceptance 等）の混入はブロック
#       * phase ラベル + priority ラベルの両方を含むことを必須とする
#       * 未登録の Label は警告のみ（カスタム Label 許容）

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

is_first_line_cmd "$CMD" '^\s*gh\s+issue\s+create\b' || exit 0

ERRORS=""
WARNINGS=""

# --- 必須オプション ---
if ! echo "$CMD" | grep -qE '\-\-assignee'; then
  ERRORS="${ERRORS}--assignee が指定されていません。\n  gh api user --jq '.login' でユーザー名を取得し、--assignee に設定してください。\n\n"
fi

if ! echo "$CMD" | grep -qE '\-\-project'; then
  ERRORS="${ERRORS}--project が指定されていません。\n  SessionStart で注入された「プロジェクト」一覧から該当プロジェクトを指定してください。\n\n"
fi

# --- --label 検証 ---
if ! echo "$CMD" | grep -qE '\-\-label'; then
  PHASE_LIST=$(taxonomy_phases | paste -sd '/' -)
  PRIO_LIST=$(taxonomy_priorities | paste -sd '/' -)
  ERRORS="${ERRORS}--label が指定されていません。フェーズ + 重要度の 2 軸を付与してください。\n  例: --label \"開発,重要度:中\"\n  フェーズ: ${PHASE_LIST}\n  重要度: ${PRIO_LIST}\n\n"
else
  LABEL_VAL=$(extract_option_value "$CMD" label)

  type_in_label=""
  phase_present=0
  priority_present=0
  unknown_labels=""

  OLD_IFS=$IFS
  IFS=','
  for label in $LABEL_VAL; do
    trimmed=$(echo "$label" | xargs)
    [ -z "$trimmed" ] && continue

    if taxonomy_is_type_word "$trimmed"; then
      type_in_label="$trimmed"
      break
    fi

    if echo "$(taxonomy_phases)" | grep -Fxq "$trimmed"; then
      phase_present=1
    elif echo "$(taxonomy_priorities)" | grep -Fxq "$trimmed"; then
      priority_present=1
    else
      unknown_labels="${unknown_labels}${unknown_labels:+, }${trimmed}"
    fi
  done
  IFS=$OLD_IFS

  if [ -n "$type_in_label" ]; then
    ERRORS="${ERRORS}--label に Type 語「${type_in_label}」が混入しています。\n  Type（Task / Bug / Feature / Minutes / Acceptance）は **GitHub Issue Type** で表現します。\n  Label は 2 軸のみ:\n    - フェーズ: $(taxonomy_phases | paste -sd '/' -)\n    - 重要度: $(taxonomy_priorities | paste -sd '/' -)\n  対応:\n    1. --label から Type 語を外す（例: --label \"開発,重要度:中\"）\n    2. Issue 作成後に updateIssueIssueType mutation で Type を設定（org リポジトリのみ）\n\n"
  else
    if [ $phase_present -eq 0 ]; then
      ERRORS="${ERRORS}--label にフェーズラベルが含まれていません。\n  候補: $(taxonomy_phases | paste -sd '/' -)\n\n"
    fi
    if [ $priority_present -eq 0 ]; then
      ERRORS="${ERRORS}--label に重要度ラベルが含まれていません。\n  候補: $(taxonomy_priorities | paste -sd '/' -)\n\n"
    fi
    if [ -n "$unknown_labels" ]; then
      WARNINGS="${WARNINGS}⚠ taxonomy.json に未登録の Label: ${unknown_labels}\n  カスタム Label として意図的なら続行可。恒常的に使うなら taxonomy に追加を検討。\n"
    fi
  fi
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

if [ -n "$WARNINGS" ]; then
  echo -e "$WARNINGS"
fi

echo "✓ Issue 作成チェック通過。重複 Issue がないことを確認済みですか？"
exit 0
