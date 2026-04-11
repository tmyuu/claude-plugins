---
description: "営業アクション（子 Issue）を作成する。親の案件 Issue に紐付け。"
---

sales-manager エージェントに委譲して、営業アクション（子 Issue）を作成してください。

## 作成内容

$ARGUMENTS

## ルール

### 親 Issue の特定
引数に `#N` が含まれる場合: 指定された Issue を親とする
含まれない場合: オープン中の案件（stage:* ラベル付き）から推論

### ラベル
- `type:task` or `type:議事録`（内容に応じて判断）
- `priority:*`（親の priority を継承、または明示指定）
- **stage ラベルは付けない**（stage は親の属性）

### タイトル形式
「顧客名 アクション内容 日付」
例: 「ABC社 初回ヒアリング 2026-04-15」「山田氏 提案書送付」

### ステータス判断
引数に `--now` が含まれる場合: **In Progress**
引数に `--later` が含まれる場合: **Todo**
どちらもない場合: ユーザーの意図を推論（デフォルト Todo）

### 作成後の処理
1. Sub-issues API で親に紐付け
2. 親 Issue のアクションアイテムにチェックリストとして追加

詳細ルールは sales-lifecycle スキルと sales-manager エージェントの定義を参照。
