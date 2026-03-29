# github-project-manager

GitHub プロジェクト管理用 Claude Code プラグイン。

Issue ライフサイクル管理、コミットガードレール、プロジェクト状態のコンテキスト注入を自動化する。

## インストール

```
/plugin install github-project-manager@tmyuu/claude-plugins
```

## 機能

### Hooks

| Hook | イベント | 機能 |
|------|---------|------|
| inject-project-state.sh | SessionStart | GitHub Projects・Issue一覧・Git状態をコンテキストに注入 |
| check-commit.sh | PreToolUse(Bash) | コミット時のIssue番号チェック（exit 2で自己修正） |
| auto-lint.sh | PostToolUse(Edit\|Write) | .ts/.tsxファイル編集後の自動ESLint |

### Commands

| コマンド | 説明 |
|---------|------|
| `/new-issue` | ルールに従ったIssue作成（タイトル・内容・ラベル・プロジェクト設定） |
| `/update-issue` | ステータス変更・アクションアイテム更新・子Issueクローズ連動 |

### Agents

| エージェント | 説明 |
|------------|------|
| issue-manager | Issue作成・更新・クローズの専門エージェント |

### Skills

| スキル | 説明 |
|--------|------|
| issue-lifecycle | Issueライフサイクルの常時読み込みルール |

## 構成

```
github-project-manager/
├── .claude-plugin/plugin.json
├── settings.json
├── agents/issue-manager.md
├── commands/
│   ├── new-issue.md
│   └── update-issue.md
├── skills/issue-lifecycle/SKILL.md
└── scripts/
    ├── inject-project-state.sh
    ├── check-commit.sh
    └── auto-lint.sh
```
