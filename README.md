# claude-plugins

Claude Code プラグインコレクション by @tmyuu

## プラグイン一覧

| プラグイン | 説明 | インストール |
|-----------|------|------------|
| [github-project-manager](plugins/github-project-manager/) | GitHub プロジェクト管理の自動化 | `/plugin install github-project-manager@tmyuu/claude-plugins` |

## インストール方法

Claude Code で以下を実行:

```
/plugin install <プラグイン名>@tmyuu/claude-plugins
```

## プラグインの追加

`plugins/` ディレクトリに新しいプラグインを追加する:

```
plugins/
├── github-project-manager/    # GitHub プロジェクト管理
├── next-plugin/               # 次のプラグイン
└── ...
```

各プラグインは `.claude-plugin/plugin.json` を含む独立したディレクトリ。
