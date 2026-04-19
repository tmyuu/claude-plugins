---
description: "GitHub Issue をルールに従って作成する。タイトルはクライアント向け、内容は経緯が追えるように。"
---

issue-manager エージェントに委譲して、以下のルールに従い Issue を作成してください。

## 作成内容

$ARGUMENTS

## ルール

### タイトル
- クライアントが読むものとして書く（技術用語を最小限に）
- 何をするかを端的に表現
- 良い例: 「LINE連携: Webhook設定・UX改善」「顧客ダッシュボードに月次レポート追加」
- 悪い例: 「fix: webhook HMAC validation error」「refactor: extract useAuth hook」

### 内容
後から見返して経緯がわかるように:
- **背景**: なぜこの作業が必要か
- **目的**: 何を達成するか
- **完了条件**: 何をもって完了とするか
- アクションアイテムがあればチェックリスト形式で記載

### 必須設定
1. `gh api user --jq '.login'` でアサイン
2. フェーズラベル + 重要度ラベル（`--label "開発,重要度:中"` 等）
3. プロジェクト紐付け（`--project` で該当プロジェクトに追加）
4. タイプ設定（`gh api graphql` で Issue Type 設定）

### 親子関係（該当する場合）
- **GitHub Sub-issues API で親子関係を設定する**（`Parent: #N` テキストは使わない）
  ```bash
  CHILD_ID=$(gh api repos/{owner}/{repo}/issues/{child} --jq '.id')
  gh api repos/{owner}/{repo}/issues/{parent}/sub_issues -F sub_issue_id="$CHILD_ID"
  ```
- 親 Issue のアクションアイテムに子をチェックリスト形式で追加（例: `- [ ] #123 子タスク概要`）
