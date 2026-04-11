# github-project-manager

GitHub プロジェクト管理用 Claude Code プラグイン。

Issue ライフサイクル管理、コミットガードレール、プロジェクト状態のコンテキスト注入を自動化する。

## インストール

```
/plugin install github-project-manager@workflow-plugins
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
| inject-project-state.sh | SessionStart | GitHub Projects・Issue一覧・Git状態をコンテキストに注入 |
| check-commit.sh | PreToolUse(Bash) | コミット時のIssue番号チェック（exit 2で自己修正） |
| check-issue-create.sh | PreToolUse(Bash) | `gh issue create` の必須オプション検証 |
| check-branch.sh | PreToolUse(Bash) | ブランチ名のIssue番号チェック |
| check-close.sh | PreToolUse(Bash) | Issueクローズ・PRマージ前の未完了チェックリスト検証（exit 2で自己修正） |
| check-issue-type.sh | PostToolUse(Bash) | Issue作成後のType設定リマインド（orgリポジトリのみ） |
| auto-update-issue-status.sh | PostToolUse(Bash) | コミット成功後にIssueステータスをIn Progressに自動更新 |
| auto-lint.sh | PostToolUse(Edit\|Write) | .ts/.tsxファイル編集後の自動ESLint |

### Commands

| コマンド | 説明 |
|---------|------|
| `/init-workflow` | CLAUDE.md を自動生成/更新し、ワークフロー設定を追記 |
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
├── settings.json           # Hooks 定義
├── agents/
│   └── issue-manager.md    # Issue管理エージェント
├── commands/
│   ├── new-issue.md        # /new-issue コマンド
│   └── update-issue.md     # /update-issue コマンド
├── skills/
│   └── issue-lifecycle/
│       └── SKILL.md        # ライフサイクルルール
└── scripts/
    ├── inject-project-state.sh
    ├── check-commit.sh
    ├── check-issue-create.sh
    ├── check-branch.sh
    ├── check-close.sh
    ├── check-issue-type.sh
    ├── auto-update-issue-status.sh
    └── auto-lint.sh
```

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

デプロイ手順と注意点。
「全関数デプロイ禁止」等の IMPORTANT ルールはここに。

## アーキテクチャ

ディレクトリ構成と主要技術スタックの概要。
フレームワーク、DB、外部API連携を簡潔に。

## ハマりどころ

Claude が間違えやすいプロジェクト固有の罠。
例: 特殊な命名規則、環境分離、独自ドメインロジック。

## GitHub ワークフロー

@.claude/skills/issue-lifecycle/SKILL.md
```

### ポイント

- **GitHub ワークフローの詳細はインポートで委譲**する。`@.claude/skills/issue-lifecycle/SKILL.md` の1行で、プラグインのスキルファイルが自動読み込みされる。CLAUDE.md にルールを重複して書かない
- **コードから読み取れる情報は書かない**: ファイル単位の説明、標準的な言語規約、API ドキュメント
- **頻繁に変わる情報は書かない**: 現在の Issue 一覧、最近の変更履歴（hooks が自動注入する）
- **チュートリアルや長い説明は書かない**: 必要ならドキュメントへのリンクを貼る

### 含めるべきもの / 含めないもの

| 含める | 含めない |
|--------|---------|
| Claude が推測できないコマンド | 標準的な `npm start` 等 |
| デフォルトと異なるコードスタイル | 言語の一般的な規約 |
| プロジェクト固有のハマりどころ | 自明なプラクティス（「きれいなコードを書け」等） |
| 環境の癖（必須の環境変数等） | 詳細な API ドキュメント |
| アーキテクチャの意思決定 | ファイル単位の説明 |

### 例: コードリポジトリ

```markdown
# MyApp

SaaS向け顧客管理プラットフォーム。

## コマンド

\```bash
pnpm install              # 依存インストール
pnpm run dev              # 開発サーバー
npx tsc --noEmit          # 型チェック
\```

## デプロイ

IMPORTANT: Functions は対象を個別指定する。`--only functions` で全関数デプロイしない。

\```bash
firebase deploy --only functions:api,functions:webhook
\```

## アーキテクチャ

\```
web/         → React + Vite
functions/   → Cloud Functions v2 + Express
\```

- **DB:** Firestore
- **認証:** Firebase Auth

## ハマりどころ

- パッケージマネージャーは **pnpm**（npm は使わない）
- コマンドは全て**リポジトリルート**から実行する

## GitHub ワークフロー

@.claude/skills/issue-lifecycle/SKILL.md
```

### 例: ドキュメントリポジトリ

```markdown
# ProjectName

企画・設計のドキュメントリポジトリ。コードなし。

## 構成

\```
phase0/  → リサーチ
phase1/  → 実装計画
\```

## ハマりどころ

- クライアント向け資料を含むため、技術用語は最小限に

## GitHub ワークフロー

@.claude/skills/issue-lifecycle/SKILL.md
```
