# github-project-manager

GitHub プロジェクト管理用 Claude Code プラグイン。

Issue のライフサイクル管理、コミットガードレール、プロジェクト状態のコンテキスト注入を自動化する。

## 機能

- **SessionStart Hook**: GitHub Projects・Issue 一覧・Git 状態をセッション開始時に注入
- **PreToolUse Hook**: コミット時の Issue 番号チェック（自己修正付き）
- **PostToolUse Hook**: .ts ファイル編集後の自動 lint
- **`/new-issue` コマンド**: ルールに従った Issue 作成
- **`/update-issue` コマンド**: ステータス・アクションアイテムの更新
- **issue-manager エージェント**: Issue 管理の専門サブエージェント
- **issue-lifecycle スキル**: Issue ライフサイクルの常時ルール

## インストール

```bash
claude /plugin install tmyuu/claude-plugins
```

## 構成

```
.claude-plugin/
├── plugin.json              # プラグインメタデータ
commands/
├── new-issue.md             # /new-issue
├── update-issue.md          # /update-issue
agents/
├── issue-manager.md         # Issue管理エージェント
skills/
└── issue-lifecycle/
    └── SKILL.md             # 常時読み込みルール
scripts/
├── inject-project-state.sh  # SessionStart 注入
├── check-commit.sh          # コミットチェック
└── auto-lint.sh             # 自動lint
```
