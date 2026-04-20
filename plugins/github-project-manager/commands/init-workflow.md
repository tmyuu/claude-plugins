---
description: "CLAUDE.md を自動生成/更新し、GitHub ワークフローのスキル参照を追記する。さらに taxonomy.json に沿って GitHub Label を同期する。"
---

プロジェクトの `.claude/CLAUDE.md` を確認し、GitHub ワークフローを導入してください。
完了後、taxonomy.json に沿って GitHub Label の同期をユーザーに提案してください。

## 手順

### 1. 現状確認
- `.claude/CLAUDE.md` が存在するか確認

### 2-A. CLAUDE.md が存在しない場合 → 新規作成

ユーザーに以下を確認してから作成:
- プロジェクト名（リポジトリ名をデフォルト提案）
- プロジェクトの一行説明

以下のテンプレートで `.claude/CLAUDE.md` を作成:

```markdown
# {プロジェクト名}

{一行説明}

## コマンド

## アーキテクチャ

## GitHub ワークフロー

@.claude/skills/issue-lifecycle/SKILL.md
```

### 2-B. CLAUDE.md が存在する場合 → 更新

1. 既に `@.claude/skills/issue-lifecycle/SKILL.md` が含まれていれば「設定済みです」と報告
2. 含まれていなければ、末尾に以下を追記:

```markdown

## GitHub ワークフロー

@.claude/skills/issue-lifecycle/SKILL.md
```

### 3. GitHub Label の同期（対話）

ユーザーに「この リポジトリの GitHub Label を taxonomy.json に合わせて同期しますか？」と確認。**破壊的変更はしない**（既存 Label は削除せず、追加と色・説明の更新のみ）。

同意が得られたら以下を実行:

#### 3.1 taxonomy の値を取得

プラグインスクリプトから読み出す（Bash で実行可能）:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
# taxonomy.sh も自動 source されるため taxonomy_* 関数が使える
```

#### 3.2 現状取得

```bash
gh label list --limit 100 --json name,color,description > /tmp/current-labels.json
```

#### 3.3 フェーズ・重要度ラベルを同期

taxonomy の `phase` / `priority` それぞれの values について:

```bash
for phase in $(taxonomy_phases); do
  color=$(taxonomy_phase_color "$phase")
  desc=$(taxonomy_phase_description "$phase")
  # 存在しなければ create、あれば edit（force で色・説明を合わせる）
  if gh label list --json name --jq '.[].name' | grep -Fxq "$phase"; then
    gh label edit "$phase" --color "$color" --description "$desc"
  else
    gh label create "$phase" --color "$color" --description "$desc"
  fi
done
# priority も同様
for prio in $(taxonomy_priorities); do
  color=$(taxonomy_priority_color "$prio")
  desc=$(taxonomy_priority_description "$prio")
  if gh label list --json name --jq '.[].name' | grep -Fxq "$prio"; then
    gh label edit "$prio" --color "$color" --description "$desc"
  else
    gh label create "$prio" --color "$color" --description "$desc"
  fi
done
```

#### 3.4 同期結果を報告

- 追加した Label 件数
- 色・説明を更新した Label 件数
- 削除はしていない旨（taxonomy に無い既存 Label は残す）

### 4. 完了報告

以下を案内:
- CLAUDE.md の変更内容
- Label 同期の結果（実行した場合）
- 利用可能なコマンド: `/new-issue`, `/new-minutes`, `/new-acceptance`, `/start #N`, `/update-issue`
- SessionStart でプロジェクト状態が自動注入されること

$ARGUMENTS
