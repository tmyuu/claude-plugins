---
description: "CLAUDE.md を自動生成/更新し、GitHub ワークフローのスキル参照を追記する"
---

プロジェクトの `.claude/CLAUDE.md` を確認し、GitHub ワークフローを導入してください。

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

1. 既に `@.claude/skills/issue-lifecycle/SKILL.md` が含まれていれば「設定済みです」と報告して終了
2. 含まれていなければ、末尾に以下を追記:

```markdown

## GitHub ワークフロー

@.claude/skills/issue-lifecycle/SKILL.md
```

### 3. 完了報告

設定が完了したら以下を案内:
- `/new-issue` で Issue を作成できること
- `/update-issue` で Issue を更新できること
- SessionStart でプロジェクト状態が自動注入されること

$ARGUMENTS
