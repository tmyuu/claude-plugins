---
description: "Acceptance タイプの検収 Issue を作成。クライアントにアサインし前工程 Issue を Blocks by で明示。検収作業自体は GitHub 上でクライアントが手動実施。"
---

検収依頼の Issue を作成してください。

## 引数

$ARGUMENTS

引数形式:
- **対象**（必須）: 検収対象の機能名・成果物
  - 例: `初期リリース機能`、`ダッシュボード月次レポート`
- **--client @handle**（必須）: クライアントの GitHub ハンドル
- **--blocks-by #N**（推奨）: 前工程 Issue 番号（実装 Issue など。複数可、カンマ区切り）
- **--project "<name>"**（任意）: 対象プロジェクト名。省略時は SessionStart のプロジェクト一覧から Claude が判断し、不確かならユーザー確認

## 手順

### 1. 前提確認

- `--client` が指定されていなければユーザーに「検収担当クライアントの GitHub ハンドル」を確認して取得
- `--blocks-by` が未指定の場合、前工程 Issue をユーザーに確認（無ければ空でよいが Minor リスクとして指摘）
- プロジェクトが特定できない場合は SessionStart の注入から候補提示

### 2. Issue 本文テンプレ

```markdown
## 検収対象

- **対象**: {引数の対象}
- **環境**: {staging / production / その他を確認}
- **対応 PR / 実装 Issue**: {Blocks by で指定された Issue をリンク表記}

## 検証手順

1. {環境 URL / アクセス方法}
2. {操作手順を簡潔に}
3. {確認すべき画面・データ}

## 確認項目

- [ ] 機能1: 期待動作...
- [ ] 機能2: 期待動作...
- [ ] {必要な項目を列挙。漏れがあれば開発側に要差し戻し}

## 承認

- [ ] クライアント（@{client-handle}）による承認

## 差し戻し手順

問題があれば:
1. このIssue をコメントで指摘（どの確認項目か、どんな現象か）
2. Issue を **reopen** する（クローズ済みの場合）
3. 開発チームが対応 → 再度 In Progress に戻す
```

### 3. Issue 作成

必須設定:
- `--title "検収: {対象}"`
- `--body "..."`（上記テンプレ）
- `--label "<フェーズ>,重要度:<クライアント確認>"` — **Label は フェーズ + 重要度の 2 軸のみ**。「検収」「acceptance」等の Type 語を Label に含めない
  - フェーズは通常 `納品`。フェーズラベル体系に応じて
- `--assignee {client-handle}` — **クライアントをアサイン**（開発者ではない）
- `--project "<プロジェクト名>"`

**Type 設定**（org リポジトリのみ）: `updateIssueIssueType` mutation で **`Acceptance`** に設定。これが検収性質を表現する一次情報。

### 4. Relationships 設定

`--blocks-by` で指定された Issue 番号それぞれについて、**BLOCKS** 関係を設定:

```bash
# 前工程 Issue の node ID を取得
BLOCKING_ID=$(gh api repos/{owner}/{repo}/issues/{blocking} --jq '.node_id')
# この Acceptance Issue の node ID を取得
BLOCKED_ID=$(gh api repos/{owner}/{repo}/issues/{acceptance} --jq '.node_id')
# 前工程 → この検収 を BLOCKS
gh api graphql -f query='
  mutation($blocking: ID!, $blocked: ID!) {
    addIssueRelation(input: {
      issueId: $blocking
      relatedIssueId: $blocked
      relationType: BLOCKS
    }) { issue { number } }
  }
' -f blocking="$BLOCKING_ID" -f blocked="$BLOCKED_ID"
```

### 5. プロジェクトステータス

- 作成直後は **Todo** に明示設定
- 前工程が完了して検収開始する段階になったら `/update-issue` で **In Progress** に遷移（= クライアント通知のタイミング）

### 6. 完了報告

- 作成した Issue 番号・URL
- アサインしたクライアントハンドル
- Blocks by で紐付けた Issue リスト
- 次アクション: 前工程完了時に `/update-issue #N in-progress` で In Progress に遷移してクライアントに通知

## 禁止事項

- **検収の承認・差し戻しを自動化しない**（クライアントが GitHub UI 上で手動実施する運用）
- アサインを開発者にしない（クライアントアサインが必須）
- 承認チェックリストを省略しない（完了条件として必要）
