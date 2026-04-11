# claude-plugins

Claude Code プラグインコレクション by @tmyuu

## プラグイン一覧

| プラグイン | 説明 | インストール |
|-----------|------|------------|
| [github-project-manager](plugins/github-project-manager/) | GitHub Issue/Project ライフサイクルの自動管理 | `/plugin install github-project-manager@claude-plugins` |
| [sales-pipeline](plugins/sales-pipeline/) | 営業パイプライン管理（stage ラベルで商談フェーズを可視化） | `/plugin install sales-pipeline@claude-plugins` |

## インストール方法

### 1. マーケットプレイスを追加

```
/plugin marketplace add tmyuu/claude-plugins
```

### 2. プラグインをインストール

```
/plugin install github-project-manager@claude-plugins
/plugin install sales-pipeline@claude-plugins
```

> `sales-pipeline` は `github-project-manager` と併用する前提で設計されています。

## プラグイン構成

```
plugins/
├── github-project-manager/    # GitHub プロジェクト管理（共通基盤）
└── sales-pipeline/            # 営業パイプライン管理
```

各プラグインは `.claude-plugin/plugin.json` を含む独立したディレクトリ。
