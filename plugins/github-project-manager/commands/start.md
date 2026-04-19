---
description: "Issue 番号を指定して作業開始。ブランチ作成 + プロジェクトステータスを In Progress に遷移する一貫エントリポイント。"
---

指定された Issue から作業を開始してください。

## 引数

$ARGUMENTS

引数は Issue 番号（例: `77` または `#77`）。省略された場合はユーザーに確認すること。

## 手順（issue-manager に委譲可能）

### 1. Issue 番号の正規化・検証

- `$ARGUMENTS` から数字部分だけを取り出す（`#77` → `77`）
- 数字でなければユーザーに確認
- `gh issue view N --json number,title,state,labels,assignees` で Issue を取得
- 取得できなければ「存在しない Issue」としてエラー報告し中断
- `state` が `CLOSED` なら警告し、ユーザーに「別件なら /new-issue、再対応なら確認」を促して中断

### 2. ブランチ作成

- Issue タイトルから短い slug を生成（英数字ハイフン、10-30 文字程度、全角は転記せず意訳してよい）
- ブランチ名: `feature/#N-<slug>`（バグ修正の場合は `fix/#N-<slug>`）
- ラベルに「bug」「バグ」が含まれていれば `fix/`、それ以外は `feature/`
- 既に同名ブランチがあれば `git checkout` で切替、無ければ `git checkout -b`
- **current branch が main/master でない場合**、ユーザーに「作業中のブランチから切り替えていいか」を確認してから切る

### 3. プロジェクトステータスを In Progress に遷移

- `list_issue_project_items` 相当の GraphQL で Issue の project items を取得
- 各アイテムの Status を `In Progress` に設定（既に In Progress / Done なら何もしない）
- 複数プロジェクトに紐づいている場合は全てに適用

### 4. 完了報告

以下を端的に報告:
- Issue #N タイトル
- 切り替えたブランチ名
- 未完了チェックリスト（あれば先頭 5 件）
- 次のアクション提案（最初のチェックリスト項目に着手など）

## 禁止事項

- Issue の新規作成はしない（このコマンドは既存 Issue での作業開始専用）
- ユーザーに確認せず他ブランチの作業を中断しない
- 既に Done になっている Issue での作業開始はユーザーに確認する
