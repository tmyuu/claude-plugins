# sales-pipeline

営業パイプライン管理用 Claude Code プラグイン。

`stage:*` ラベルで商談フェーズ（lead → appointment → meeting → proposal → deal / lost）を管理し、GitHub Issue/Project で営業進捗を可視化する。`github-project-manager` と併用する前提で設計。

## インストール

```
/plugin install github-project-manager@workflow-plugins
/plugin install sales-pipeline@workflow-plugins
```

## セットアップ

インストール後に以下を実行すると、CLAUDE.md にワークフロー設定が自動追加されます:

```
/init-workflow
```

## 機能

### Hooks

| Hook | イベント | 機能 |
|------|---------|------|
| inject-sales-state.sh | SessionStart | パイプライン概況（stage 別案件一覧）をコンテキストに注入 |
| auto-advance-stage.sh | PostToolUse(Bash) | 子 Issue クローズ時に親の stage ラベル更新を提案 |

### Commands

| コマンド | 説明 |
|---------|------|
| `/init-workflow` | CLAUDE.md を自動生成/更新し、営業ワークフロー設定を追記 |
| `/new-deal` | 営業案件（親 Issue）を作成（stage:lead をデフォルト付与） |
| `/new-action` | アクション（子 Issue）を作成し、親案件に紐付け |

### Agents

| エージェント | 説明 |
|------------|------|
| sales-manager | 営業 Issue の作成・更新・stage 管理の専門エージェント |

### Skills

| スキル | 説明 |
|--------|------|
| sales-lifecycle | 営業パイプラインのライフサイクル原則（stage ラベル、親子構造） |

## stage ラベル

| ラベル | フェーズ | 意味 |
|---|---|---|
| `stage:lead` | リード | 接点獲得 |
| `stage:appointment` | アポイント | 打ち合わせ日程確定 |
| `stage:meeting` | 打ち合わせ | 打ち合わせ実施中 |
| `stage:proposal` | 提案 | 提案書提出 |
| `stage:deal` | 案件化 | 受注 |
| `stage:lost` | 失注 | 不成立 |

## 構成

```
sales-pipeline/
├── settings.json           # Hooks 定義
├── agents/
│   └── sales-manager.md    # 営業管理エージェント
├── commands/
│   ├── init-workflow.md    # /init-workflow コマンド
│   ├── new-deal.md         # /new-deal コマンド
│   └── new-action.md       # /new-action コマンド
├── skills/
│   └── sales-lifecycle/
│       └── SKILL.md        # 営業ライフサイクル原則
└── scripts/
    ├── inject-sales-state.sh
    └── auto-advance-stage.sh
```
