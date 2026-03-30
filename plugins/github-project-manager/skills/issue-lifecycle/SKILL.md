---
name: issue-lifecycle
description: "Issue ライフサイクルのルール。コミット・Issue 作成・PR・マージ時に自動適用される。"
user-invocable: false
---

# Issue ライフサイクルルール

## ワークフロー

IMPORTANT: コード変更を伴う作業を開始する前に、以下のフローに従う。ユーザーからの明示的な指示がなくても自動で実行すること。

1. **Issue 確認** — SessionStart で注入された Issue 一覧から、対応する Issue があるか確認する
2. **Issue 作成** — なければ `/new-issue` で先に作成する
3. **ブランチ作成** — `feature/#N-description` or `fix/#N-description` で切る
4. **コード変更** — 作業を行う
5. **コミット** — Issue 番号を含めてコミットする
6. **PR 作成** — `Closes #N` を含めて PR を作る
7. **Issue 更新** — ステータスを作業状態に合わせて更新する

## ルール

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

## ブランチ

- ブランチ名に **Issue 番号を含める**: `feature/#N-description` or `fix/#N-description`
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

## 検収

- Acceptance タイプの Issue が進行中になると、クライアントに自動通知される
- 検収承認でクローズ、差し戻しで再オープン

## プロジェクト

- プロジェクト作成前に**既存プロジェクト一覧を確認**し、該当するものがあれば使う
- プロジェクト作成後は必ず**リポジトリにリンク**する（`linkProjectV2ToRepository`）
- リンクしないとリポジトリの Projects タブに表示されない
- Issue は `--project` でプロジェクトに紐付ける

## やってはいけないこと

- Issue 番号なしのコミット
- ラベルやタイプの後からの変更（原則。typo 修正は可）
- ユーザーに確認せずに Issue をクローズ
- `git push --force` を main ブランチに実行
- プロジェクトをリポジトリにリンクせずに放置
