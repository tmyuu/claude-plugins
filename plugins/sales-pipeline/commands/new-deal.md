---
description: "営業案件（親 Issue）を作成する。顧客名と案件概要を指定。"
---

sales-manager エージェントに委譲して、営業案件（親 Issue）を作成してください。

## 作成内容

$ARGUMENTS

## ルール

### stage ラベルの初期値
引数に `--stage` が含まれる場合: 指定されたフェーズで作成
- 例: `--stage appointment`

含まれない場合: **stage:lead** をデフォルトで付与

### ステータス判断
引数に `--now` が含まれる場合: **In Progress** で作成
引数に `--later` が含まれる場合: **Todo** で作成
どちらもない場合: ユーザーの意図を推論（デフォルト In Progress）

### 必須情報
- 顧客名（会社名 or 個人名）
- 案件概要（何の相談・提案か）

### タイトル形式
「顧客名 — 案件概要」
例: 「ABC株式会社 — DX支援案件」「山田太郎氏 — コンサル相談」

詳細ルールは sales-lifecycle スキルと sales-manager エージェントの定義を参照。
