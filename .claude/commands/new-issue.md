---
description: "GitHub Issue をルールに従って作成する。タイトルはクライアント向け、内容は経緯が追えるように。"
---

issue-manager エージェントに委譲して、Issue を作成してください。

## 作成内容

$ARGUMENTS

## ステータス判断ルール

引数に `--now` が含まれる場合: **In Progress** で作成
- `CLAUDE_ISSUE_STATUS=in_progress gh issue create ...` で実行

引数に `--later` が含まれる場合: **Todo** で作成
- 通常の `gh issue create ...` で実行

どちらもない場合: **ユーザーの意図を推論**
- 「すぐ作業」「今から実装」「〜して」等 → In Progress
- 「あとで」「Issue だけ立てて」「記録として」等 → Todo
- 不明な場合はデフォルト Todo

詳細ルールは issue-lifecycle Skill と issue-manager エージェントの定義を参照。
