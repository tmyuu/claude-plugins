#!/bin/bash
# PreToolUse: gh pr create の必須オプション・Label 規則・Closes 検証
#   - --assignee / --project 必須
#   - --label: Type 語混入禁止、フェーズ + 重要度の 2 軸が揃うこと
#   - --body に Closes #N 必須

source "$(dirname "$0")/lib.sh"

has_jq || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | read_command)

is_first_line_cmd "$CMD" '^\s*gh\s+pr\s+create\b' || exit 0

ERRORS=""
WARNINGS=""

if ! echo "$CMD" | grep -qE '\-\-assignee'; then
  ERRORS="${ERRORS}--assignee が指定されていません。\n  gh api user --jq '.login' でユーザー名を取得し、--assignee に設定してください。\n\n"
fi

if ! echo "$CMD" | grep -qE '\-\-project'; then
  ERRORS="${ERRORS}--project が指定されていません。対応 Issue と同じプロジェクトに紐付けてください。\n\n"
fi

if ! echo "$CMD" | grep -qiE '(closes?|fix(es)?|resolves?)\s+#[0-9]+'; then
  ERRORS="${ERRORS}PR 本文に Closes #N が含まれていません。\n  対応 Issue を自動クローズするため、--body に \"Closes #N\" を記載してください。\n\n"
fi

if ! echo "$CMD" | grep -qE '\-\-label'; then
  PHASE_LIST=$(taxonomy_phases | paste -sd '/' -)
  PRIO_LIST=$(taxonomy_priorities | paste -sd '/' -)
  ERRORS="${ERRORS}--label が指定されていません。対応 Issue と同じ 2 軸のラベルを付与してください。\n  例: --label \"開発,重要度:中\"\n  フェーズ: ${PHASE_LIST}\n  重要度: ${PRIO_LIST}\n\n"
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
    ERRORS="${ERRORS}--label に Type 語「${type_in_label}」が混入しています。\n  Type は GitHub Issue Type で表現します（PR に Type の概念は無いため、PR ラベルは対応 Issue と同じ 2 軸に合わせる）。\n\n"
  else
    if [ $phase_present -eq 0 ]; then
      ERRORS="${ERRORS}--label にフェーズラベルが含まれていません。\n  候補: $(taxonomy_phases | paste -sd '/' -)\n\n"
    fi
    if [ $priority_present -eq 0 ]; then
      ERRORS="${ERRORS}--label に重要度ラベルが含まれていません。\n  候補: $(taxonomy_priorities | paste -sd '/' -)\n\n"
    fi
    if [ -n "$unknown_labels" ]; then
      WARNINGS="${WARNINGS}⚠ taxonomy.json に未登録の Label: ${unknown_labels}\n"
    fi
  fi
fi

if [ -n "$ERRORS" ]; then
  {
    echo "gh pr create に問題があります:"
    echo ""
    echo -e "$ERRORS"
  } >&2
  exit 2
fi

if [ -n "$WARNINGS" ]; then
  echo -e "$WARNINGS"
fi

exit 0
