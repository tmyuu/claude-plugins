# github-project-manager

GitHub を「型に沿って使いこなす PM」として振る舞う Claude Code プラグイン。
Issue 作成 → ブランチ → 実装 → PR → マージ → クローズ の全工程を、
**ハードゲート（確定違反のブロック）** + **LLM 推論型監査（SessionStart で状態注入 → Claude が整合性を判断）** の
ハイブリッドで一貫させる。

## インストール

```
/plugin install github-project-manager@workflow-plugins
```

## セットアップ

```
/init-workflow
```

CLAUDE.md に `@.claude/skills/issue-lifecycle/SKILL.md` が追記され、ルールが常時読み込まれる。

## ワークフロー

```
  [起点コマンド]                                [作業開始]
   ┌─ /new-issue       (Task/Bug/Feature) ─┐
   ├─ /new-minutes     (議事録)            │
   └─ /new-acceptance  (検収)              │       /start #N
                                           ▼          │
                                     [Issue 作成] ────┘
                                           │  open/重複確認
                                           │  ブランチ作成
                                           │  Status: Todo → In Progress
                                           ▼
                                    [コミット／実装]
                                           │  コミットメッセージに #N 必須
                                           │  未完了項目は /update-issue で都度埋める
                                           ▼
                                       [PR 作成]
                                           │  Closes #N 必須
                                           ▼
                                   [PR マージ／クローズ]
                                           │  未完了チェックあればブロック
                                           │  Status → Done に自動遷移
                                           │  親 Issue のチェックリストを自動連動
                                           ▼
                                      [Issue Closed]

  ※ Acceptance は作成後の検収作業（承認/差戻し）をクライアントが GitHub 上で手動実施

         ─── SessionStart で常時監査 ───
         ● チェック未完了×Closed / ステータス乖離
         ● リポリンク切れ / Closed プロジェクトに Open Issue
         → 検出したら issue-manager をバックグラウンド起動で修復
```

## Commands

| コマンド | 説明 |
|---------|------|
| `/init-workflow` | CLAUDE.md を生成/更新しワークフロー設定を追記 |
| `/new-issue` | ルールに従った Issue 作成（Task/Bug/Feature 向け汎用） |
| `/new-minutes` | **議事録 md を読み取って Minutes Issue 化**（md 未作成なら `docs/meetings/` にテンプレ生成） |
| `/new-acceptance` | **検収 Issue 作成**。クライアントアサイン・前工程 Blocks by・承認チェックリスト。検収作業は GitHub 上でクライアントが手動実施 |
| `/start #N` | **作業開始の一貫エントリポイント**: 実在・open 検証 → ブランチ作成 → Status In Progress |
| `/update-issue` | ステータス変更・アクションアイテム更新・子 Issue クローズ連動 |

## Hooks

ハードゲート（`guard-*.sh`）・自動処理（`auto-*.sh`）・注入（`inject-*.sh`）・リマインド（`review-*.sh`）で命名を統一。

| Hook | イベント | 機能 |
|------|---------|------|
| inject-project-state.sh | SessionStart | プロジェクト/Issue/Git 状態を注入。**チェック未完了×Closed** 等の異常も検出 |
| review-prompt.sh | UserPromptSubmit | ブランチに応じた行動指針注入。feature/#N 上では**指示範囲外警告**も含む |
| guard-main-branch-edit.sh | PreToolUse(Edit/Write) | main 上のソースコード編集をブロック |
| guard-commit.sh | PreToolUse(Bash) | コミットメッセージの Issue 番号チェック |
| guard-branch.sh | PreToolUse(Bash) | ブランチ名の Issue 番号＋**実在・状態(open)検証** |
| guard-close.sh | PreToolUse(Bash) | `gh issue close` / `gh issue edit --state closed` / `gh pr merge` / `gh api graphql closeIssue\|updateIssue{state:CLOSED}` **全経路**で未完了チェックリスト検証 |
| guard-issue-create.sh | PreToolUse(Bash) | `gh issue create` の必須オプション検証 |
| guard-pr-create.sh | PreToolUse(Bash) | `gh pr create` の必須オプション＋Closes #N 検証 |
| guard-project-create.sh | PreToolUse(Bash) | プロジェクト新規作成をブロック（既存への紐付けが原則） |
| review-issue-type.sh | PostToolUse(Bash) | org リポジトリでの Issue Type 設定リマインド |
| auto-status-transition.sh | PostToolUse(Bash) | commit → In Progress、close/merge → Done を一元化 |
| auto-update-parent-checklist.sh | PostToolUse(Bash) | `gh issue close` **と** `gh pr merge` 両方で親 Issue のチェックリスト自動更新 |
| auto-lint.sh | PostToolUse(Edit\|Write) | .ts/.tsx ファイル編集後の自動 ESLint |

## Agents

| エージェント | 説明 |
|------------|------|
| issue-manager | Issue 作成・更新・クローズの専門エージェント |

## Skills

| スキル | 説明 |
|--------|------|
| issue-lifecycle | Issue ライフサイクルの常時読み込みルール |

## 構成

```
github-project-manager/
├── hooks/
│   └── hooks.json
├── agents/
│   └── issue-manager.md
├── commands/
│   ├── init-workflow.md
│   ├── new-issue.md
│   ├── new-minutes.md
│   ├── new-acceptance.md
│   ├── start.md
│   └── update-issue.md
├── skills/
│   └── issue-lifecycle/SKILL.md
└── scripts/
    ├── lib.sh                         # 共通関数（Issue 番号抽出・リポ情報・Project v2 GraphQL 等）
    ├── inject-project-state.sh
    ├── review-prompt.sh
    ├── review-issue-type.sh
    ├── guard-main-branch-edit.sh
    ├── guard-commit.sh
    ├── guard-branch.sh
    ├── guard-close.sh
    ├── guard-issue-create.sh
    ├── guard-pr-create.sh
    ├── guard-project-create.sh
    ├── auto-status-transition.sh
    ├── auto-update-parent-checklist.sh
    └── auto-lint.sh
```

## 設計方針

### ハードゲート（bash で確定違反をブロック）
Issue 番号なしコミット、未完了チェックリストでのクローズ、main ブランチでの直接編集など、
**ルールとして明確に違反とわかるもの**は hook で即ブロックし stderr で自己修正を促す。

### LLM 推論型監査（SessionStart で状態を注入）
プロジェクト・Issue・Git 状態を包括的に出力し、Claude 自身が整合性を判断する。
矛盾を見つけたら issue-manager サブエージェントをバックグラウンドで起動して修復。

> 「監査役が裏で常に回っている」イメージ。bash でパターン列挙するのではなく、
> 全状態をデータとして出し、LLM に推論させる。

## CLAUDE.md の書き方

プラグイン導入後、リポジトリの `.claude/CLAUDE.md` を以下のガイドラインに従って書く。

### 基本方針（[Anthropic ベストプラクティス](https://code.claude.com/docs/en/memory)準拠）

- **200行以内**に収める。長いと遵守率が下がる
- **Claude がコードから推測できない情報だけ**を書く
- 各行に「これを消したら Claude がミスするか？」と問う。No なら削除
- 重要なルールには `IMPORTANT:` を付けて強調

### 推奨セクション構成

```markdown
# プロジェクト名

プロジェクトの一行説明。

## コマンド

開発・ビルド・テスト・デプロイのコマンド一覧。
Claude が推測できないもの（カスタムスクリプト、特殊なフラグ等）を書く。

## デプロイ

デプロイ手順と注意点。「全関数デプロイ禁止」等の IMPORTANT ルールはここに。

## アーキテクチャ

ディレクトリ構成と主要技術スタックの概要。

## ハマりどころ

Claude が間違えやすいプロジェクト固有の罠。

## GitHub ワークフロー

@.claude/skills/issue-lifecycle/SKILL.md
```

### ポイント

- **GitHub ワークフローの詳細はインポートで委譲**する（`@.claude/skills/issue-lifecycle/SKILL.md` の1行）
- コードから読み取れる情報は書かない（ファイル単位の説明、標準的な言語規約、API ドキュメント）
- 頻繁に変わる情報は書かない（現在の Issue 一覧は hooks が自動注入する）
- チュートリアルや長い説明は書かない
