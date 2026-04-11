---
name: sales-lifecycle
description: "営業パイプラインの Issue ライフサイクル原則。stage ラベルによる商談フェーズ管理と親子構造の指針。"
user-invocable: false
---

# 営業パイプライン ライフサイクル原則

このスキルは **github-project-manager（issue-lifecycle）を前提** とした営業固有の判断基準を記述する。
共通ルール（コミット・ブランチ・ステータス遷移・親子関係の機械的ルール）は issue-lifecycle に従う。

## 営業の Issue 構造

### 親 Issue = 案件（Deal）
- 顧客との商談全体を表す
- タイトル例: 「ABC株式会社 — DX支援案件」「山田太郎氏 — コンサル相談」
- `stage:*` ラベルで商談フェーズを管理
- アクションアイテムに子 Issue をチェックリストとして記載

### 子 Issue = アクション（Action）
- 個別の打ち合わせ・タスク・提案書作成など
- タイトル例: 「ABC社 初回ヒアリング 2026-04-15」「提案書ドラフト作成」
- `type:*` ラベルは既存のまま（task, 議事録 等）
- 親 Issue に Sub-issues API で紐付け

## stage ラベル（商談フェーズ）

**親 Issue（案件）に付与する。子 Issue には付けない。**

| ラベル | フェーズ | 意味 |
|---|---|---|
| `stage:lead` | リード | 接点獲得。名刺交換・紹介を受けた段階 |
| `stage:appointment` | アポイント | 打ち合わせの日程が確定した段階 |
| `stage:meeting` | 打ち合わせ | 打ち合わせを実施中。壁打ち・ヒアリングを重ねている |
| `stage:proposal` | 提案 | 提案書を提出した段階 |
| `stage:deal` | 案件化 | 受注・案件として成立 |
| `stage:lost` | 失注 | 不成立。理由をコメントに記録して Close |

### フェーズ遷移の原則
- 一方向が基本: lead → appointment → meeting → proposal → deal
- 戻りもあり得る: proposal → meeting（再ヒアリング）
- `stage:lost` はどのフェーズからも遷移可能
- `stage:deal` に到達しても Issue は Close しない（案件化後の作業が続く）
- Close するのは案件完了時または失注時

### フェーズ更新のタイミング
- 子 Issue の完了をトリガーに、親の stage 更新を**提案**する（自動変更はしない）
- 例: `type:議事録` の子が Close → 親が `stage:appointment` なら `stage:meeting` を提案

## Issue の書き方（営業向け）

### 親 Issue（案件）の本文
```markdown
## 背景
- 顧客: ABC株式会社
- 担当者: 山田太郎（取締役）
- 経路: 交流会（〇〇勉強会 2026-04-10）

## 目的
DX支援の提案・案件化

## 完了条件
- [ ] 初回ヒアリング完了
- [ ] 課題整理・提案方針決定
- [ ] 提案書提出
- [ ] 受注判定
```

### 子 Issue（アクション）の本文
```markdown
## 背景
ABC社 DX支援案件（#100）の初回打ち合わせ

## 目的
課題のヒアリングと関係構築

## 完了条件
- [ ] 打ち合わせ実施
- [ ] 議事録作成
- [ ] 次のアクション決定
```

## 重要度（priority）

既存の priority ラベルをそのまま使用:
- `priority:high` — 大型案件、期限が近い、重要顧客
- `priority:medium` — 通常の商談
- `priority:low` — 長期的な関係構築、すぐの案件化は見込まない

## プロジェクト

- 営業用の GitHub Project（例: 「営業パイプライン」）に紐付け
- Board ビューで stage ラベルごとにグループ化すると全体俯瞰が可能
- 既存プロジェクトがあれば必ずそちらを使う（新規作成は最小限）

## 失注時の対応

1. 親 Issue の stage ラベルを `stage:lost` に変更
2. 失注理由をコメントに記録（予算・タイミング・競合等）
3. 親 Issue を Close
4. 未完了の子 Issue があれば `--reason "not planned"` で Close

## やってはいけないこと

- 子 Issue に `stage:*` ラベルを付ける（stage は親のみ）
- stage ラベルを複数同時に付ける（常に1つ）
- 顧客情報を Issue タイトルに過剰に含める（社名 + 案件概要で十分）
- 失注理由を記録せずに Close
