#!/bin/bash
# taxonomy.json の読み出し関数群。
# 参照順:
#   1. リポの .claude/workflow-taxonomy.json（存在すれば優先）
#   2. プラグイン同梱の config/taxonomy.json（デフォルト）
# lib.sh から自動で source される。

_TAXONOMY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_TAXONOMY_DEFAULT="$_TAXONOMY_SCRIPT_DIR/../config/taxonomy.json"

# 使用する taxonomy ファイルのパスを返す
taxonomy_file() {
  local git_root override
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$git_root" ]; then
    override="$git_root/.claude/workflow-taxonomy.json"
    if [ -f "$override" ] && jq empty "$override" >/dev/null 2>&1; then
      echo "$override"
      return 0
    fi
  fi
  echo "$_TAXONOMY_DEFAULT"
}

# --- Label ---

taxonomy_phases()     { jq -r '.labels.phase.values[].name'    "$(taxonomy_file)" 2>/dev/null; }
taxonomy_priorities() { jq -r '.labels.priority.values[].name' "$(taxonomy_file)" 2>/dev/null; }

# phase + priority を合わせた有効ラベル一覧
taxonomy_valid_label_names() {
  { taxonomy_phases; taxonomy_priorities; }
}

taxonomy_phase_color() {
  jq -r --arg n "$1" '.labels.phase.values[] | select(.name == $n) | .color // ""' "$(taxonomy_file)" 2>/dev/null
}

taxonomy_phase_description() {
  jq -r --arg n "$1" '.labels.phase.values[] | select(.name == $n) | .description // ""' "$(taxonomy_file)" 2>/dev/null
}

taxonomy_priority_color() {
  jq -r --arg n "$1" '.labels.priority.values[] | select(.name == $n) | .color // ""' "$(taxonomy_file)" 2>/dev/null
}

taxonomy_priority_description() {
  jq -r --arg n "$1" '.labels.priority.values[] | select(.name == $n) | .description // ""' "$(taxonomy_file)" 2>/dev/null
}

# --- Type ---

taxonomy_types() { jq -r '.types.values[].name' "$(taxonomy_file)" 2>/dev/null; }

# --label に混入してはいけない語（Type 名・日本語エイリアス）
taxonomy_type_words_blocked_in_labels() {
  jq -r '.types.typeWordsToBlockInLabels[]' "$(taxonomy_file)" 2>/dev/null
}

# 指定語が Type 語（大文字小文字無視）ならば exit 0
taxonomy_is_type_word() {
  local word="$1"
  local lower
  lower=$(echo "$word" | tr '[:upper:]' '[:lower:]')
  while IFS= read -r blocked; do
    [ -z "$blocked" ] && continue
    local blocked_lower
    blocked_lower=$(echo "$blocked" | tr '[:upper:]' '[:lower:]')
    if [ "$lower" = "$blocked_lower" ]; then
      return 0
    fi
  done < <(taxonomy_type_words_blocked_in_labels)
  return 1
}

# --- Status ---

taxonomy_statuses() { jq -r '.status.flow[]' "$(taxonomy_file)" 2>/dev/null; }

# 指定トリガーの遷移先ステータスを返す（なければ空文字）
# usage: taxonomy_transition_to commit|close|merge
taxonomy_transition_to() {
  jq -r --arg t "$1" '.status.transitions[] | select(.trigger == $t) | .to // ""' "$(taxonomy_file)" 2>/dev/null | head -1
}

# 指定トリガーの遷移元ステータス制約（なければ空文字 = 任意から遷移可）
taxonomy_transition_from() {
  jq -r --arg t "$1" '.status.transitions[] | select(.trigger == $t) | .from // ""' "$(taxonomy_file)" 2>/dev/null | head -1
}
