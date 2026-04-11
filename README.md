# workflow-plugins

Claude Code プラグインコレクション by @tmyuu

## プラグイン一覧

| プラグイン | 説明 | インストール |
|-----------|------|------------|
| [github-project-manager](plugins/github-project-manager/) | GitHub Issue/Project ライフサイクルの自動管理 | `/plugin install github-project-manager@workflow-plugins` |
| [sales-pipeline](plugins/sales-pipeline/) | 営業パイプライン管理（stage ラベルで商談フェーズを可視化） | `/plugin install sales-pipeline@workflow-plugins` |

## インストール方法

### 1. マーケットプレイスを追加

```
/plugin marketplace add tmyuu/workflow-plugins
```

### 2. プラグインをインストール

```
/plugin install github-project-manager@workflow-plugins
/plugin install sales-pipeline@workflow-plugins
```

> `sales-pipeline` は `github-project-manager` と併用する前提で設計されています。

### 3. CLAUDE.md をセットアップ

```
/init-workflow
```

CLAUDE.md が自動生成/更新され、ワークフローのスキル参照が追記されます。

### 4. 自動更新を有効にする（推奨）

1. `/plugin` でプラグインマネージャーを開く
2. **Marketplaces** タブ → `workflow-plugins` を選択
3. **Enable auto-update** を選択

有効にすると、Claude Code 起動時に自動で最新版に更新されます。

### 手動更新

```
/plugin update github-project-manager@workflow-plugins
/plugin update sales-pipeline@workflow-plugins
```

## プラグイン構成

```
plugins/
├── github-project-manager/    # GitHub プロジェクト管理（共通基盤）
└── sales-pipeline/            # 営業パイプライン管理
```

各プラグインは `.claude-plugin/plugin.json` を含む独立したディレクトリ。
