---
description: "CLAUDE.md を自動生成/更新し、営業パイプラインのスキル参照を追記する"
---

プロジェクトの `.claude/CLAUDE.md` を確認し、営業パイプラインワークフローを導入してください。

## 前提

このプラグインは `github-project-manager` と併用する前提です。
CLAUDE.md には issue-lifecycle と sales-lifecycle の両方のスキル参照が必要です。

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

## 営業パイプライン

@.claude/skills/sales-lifecycle/SKILL.md
```

### 2-B. CLAUDE.md が存在する場合 → 更新

1. `@.claude/skills/issue-lifecycle/SKILL.md` が含まれていなければ追記:

```markdown

## GitHub ワークフロー

@.claude/skills/issue-lifecycle/SKILL.md
```

2. `@.claude/skills/sales-lifecycle/SKILL.md` が含まれていなければ追記:

```markdown

## 営業パイプライン

@.claude/skills/sales-lifecycle/SKILL.md
```

3. 両方とも設定済みなら「設定済みです」と報告して終了

### 3. 完了報告

設定が完了したら以下を案内:
- `/new-deal` で営業案件を作成できること
- `/new-action` でアクション（子 Issue）を作成できること
- `/new-issue` `/update-issue` も引き続き利用可能
- SessionStart でパイプライン概況が自動注入されること

$ARGUMENTS
