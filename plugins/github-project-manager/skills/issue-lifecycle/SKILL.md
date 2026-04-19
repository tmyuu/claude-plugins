---
name: issue-lifecycle
description: "Issue ライフサイクルのルール。コミット・Issue 作成・PR・マージ時に自動適用される。"
user-invocable: false
---

# Issue ライフサイクルルール

以下のルールは常に意識すること。

## コミット

- コミットメッセージには**必ず Issue 番号（#N）を含める**
- 対応する Issue がなければ、先に Issue を立てる
- 「既存 Issue の延長」と思っても、作業内容が変わっていれば新しい Issue を立てる
- コミットメッセージは日本語で、変更の「何を・なぜ」を簡潔に書く

## Issue 作成

- 作成前に**既存のオープン Issue を確認**し、重複がないか確認する
- 同じ目的の Issue が既にあれば新規作成しない
- タイトルは**クライアントが読むもの**として書く（技術用語を最小限に）
- 内容は**後から見返して経緯がわかる**ように書く（背景・目的・完了条件）
- アクションアイテムは**チェックリスト形式**で分解
- ラベル（フェーズ + 重要度）・タイプ・アサイン・プロジェクト紐付けを**全て設定**
- タイプは GraphQL API で設定（`gh issue create` では設定不可）
- 親子関係は **GitHub Sub-issues（relationships）** で設定する（`Parent: #N` テキストは使わない）

## Issue 更新

- ステータスは作業状態に応じて正確に切り替える（Todo → In Progress → Done）
- 子 Issue をクローズしたら、親 Issue のアクションアイテムも `- [x]` に更新する
- 子 Issue のクローズと親のチェック更新は**セットで行う**
- **チェックリストが全て埋まっていない Issue をクローズしない**
  - `gh issue close` / `gh pr merge` / `gh issue edit --state closed` / graphql `closeIssue` は全てブロックされる
  - 閉じたい場合は先に /update-issue でチェックを埋めるか、ユーザーに「この項目は対応不要か」を確認

## 作業開始

- Issue が確定したら `/start #N` で作業開始する（推奨エントリポイント）
  - Issue の実在・open 状態を検証
  - `feature/#N-description` ブランチを作成
  - プロジェクトステータスを In Progress に遷移
- 手動で始める場合も同じ 3 つのステップを全て実施する

## ブランチ

- ブランチ名に **Issue 番号を含める**: `feature/#N-description` or `fix/#N-description`
- ブランチ切替時に Issue の **実在・状態(open)が検証される**（存在しない / closed ならブロック）
- GitHub が自動的に Development サイドバーにリンクする

## PR

- PR 本文に `Closes #N` を含める（マージで自動クローズ + Development リンク）
- Issue をクローズせずにリンクだけしたい場合は `Refs #N`
- PR タイトルは短く（70文字以内）、詳細は本文に

## Relationships

- 親子関係は **Sub-issues API** で設定する
- 依存関係がある場合は **Blocks / Blocked by** を設定する
  - 例: テスト完了 → 検収送付（テスト Issue が検収 Issue を Blocks）
- 重複 Issue は **Duplicates** でマークしクローズ

## 議事録（Minutes）

- `/new-minutes <md-path or slug>` で作成する
- md の置き場は **`docs/meetings/YYYY-MM-DD-<slug>.md` 固定**
- md を一次情報として扱い、Issue 本文には md への相対リンクを必ず残す
- md が無ければコマンドはテンプレを生成して中断する（= 編集してから再実行）
- アクションアイテムは後から **`/new-issue` で子 Task に切り出し**、Sub-issues API で親 Minutes に紐付け
- ラベル・ステータス管理は他タイプと同じ（フェーズ + 重要度、Todo → In Progress → Done）

## 検収（Acceptance）

- `/new-acceptance <対象> --client @handle --blocks-by #N` で作成する
- **アサインはクライアント**（開発者ではない）
- 前工程 Issue は **Blocks by** で明示する（実装 Issue → 検収 Issue を Blocks）
- 作成後の**検収作業（承認 / 差し戻し）はクライアントが GitHub 上で手動実施**する（自動化しない）
  - 承認: クライアントがチェックリストを埋めて Issue をクローズ
  - 差し戻し: クライアントが Issue をコメントで指摘し reopen
- Status は前工程完了時に `/update-issue` で In Progress に遷移させる（= クライアントに通知が飛ぶタイミング）
- ラベル: 納品 / 検収フェーズ + 重要度

## プロジェクト

- プロジェクト作成前に**既存プロジェクト一覧を確認**し、該当するものがあれば使う
- プロジェクト作成後は必ず**リポジトリにリンク**する（`linkProjectV2ToRepository`）
- リンクしないとリポジトリの Projects タブに表示されない
- Issue は `--project` でプロジェクトに紐付ける

## 作業の分割判断

作業中に以下のいずれかに該当すると判断したら、サブ Issue に分割する:

- **独立した変更が複数ある**: 1つの Issue に対して、互いに依存しない複数の変更が必要な場合
- **スコープが膨らんでいる**: 作業を進める中で当初の想定を超える変更が必要になった場合
- **別の問題を発見した**: 作業中にバグや改善点を見つけたが、今の Issue とは直接関係ない場合

### 分割の進め方
1. 現在の Issue の作業を一旦区切る
2. ユーザーに「この部分はサブ Issue に切り出します」と報告
3. issue-manager でサブ Issue を作成（Sub-issues API で親子関係を設定）
4. 親 Issue のアクションアイテムにサブ Issue をチェックリストとして追加
5. 現在の Issue の残り作業に集中する

### 分割しない場合
- 変更が小さく、1コミットで完結する場合
- 変更同士が強く依存していて分割すると逆に複雑になる場合

## やってはいけないこと

- Issue 番号なしのコミット
- 未完了チェックリストを残したまま Issue / PR をクローズ（全経路でブロックされる）
- ラベルやタイプの後からの変更（原則。typo 修正は可）
- ユーザーに確認せずに Issue をクローズ
- `git push --force` を main ブランチに実行
- プロジェクトをリポジトリにリンクせずに放置
- `feature/#N` ブランチ上で **Issue #N の範囲外の作業**を始める（範囲外なら /new-issue で別 Issue を立てる）
