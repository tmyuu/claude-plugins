---
description: "議事録 md から Minutes タイプの GitHub Issue を作成する。md が未作成ならテンプレを出力し編集を促す 2 段階フロー。"
---

議事録 md を読み取って Minutes タイプの Issue を作成してください。

## 引数

$ARGUMENTS

引数は以下のいずれか:
- md ファイルパス（リポジトリ相対）: 例 `docs/meetings/2026-04-19-kickoff.md`
- スラッグ単体: 例 `2026-04-19-kickoff` → `docs/meetings/<slug>.md` に展開
- 省略: ユーザーに会議タイトルと日付を確認し、スラッグを組み立てる（`YYYY-MM-DD-<slug>`）

## 置き場の規約

`docs/meetings/YYYY-MM-DD-<slug>.md` 固定。ディレクトリが無ければ作成する。

## 手順

### 1. パスの確定

1. 引数を正規化して `TARGET_PATH` を決定
2. `docs/meetings/` ディレクトリが無ければ `mkdir -p` で作成

### 2. md の存在判定

#### 2-A. md が存在しない場合 → テンプレ生成して中断

以下のテンプレで md を作成し、ユーザーに「編集してから再度 `/new-minutes <path>` を実行」と案内して終了（Issue 化しない）:

```markdown
# 議事録: {会議タイトル}

## 日時
YYYY-MM-DD HH:MM-HH:MM

## 参加者
- @handle1
- @handle2

## 議題
- topic1
- topic2

## 議論内容
(自由記述)

## 決定事項
- 決定1
- 決定2

## アクションアイテム
- [ ] 誰が / 何を / いつまでに
- [ ] （子 Issue として切り出す場合はここにチェックリスト）

## 補足
```

#### 2-B. md が存在する場合 → 読み取って Issue 化

md の内容を読み、以下に沿って Issue 本文を構成する:

```markdown
## 会議情報

- **日時**: {md から抽出}
- **参加者**: {md から抽出}
- **議事録 (md)**: [{relative-path}]({relative-path})

## 議題

{md の議題セクションをそのまま転記}

## 決定事項

{md の決定事項をそのまま転記}

## アクションアイテム

{md のアクションアイテムを `- [ ]` 形式で転記。各項目について「子 Issue 化が必要なら /new-issue で分割する」とコメント}

## 元 md 全文

<details>
<summary>展開</summary>

{md 全文}

</details>
```

### 3. Issue 作成

必須設定:
- `--title "議事録: {会議タイトル} ({日付})"`
- `--body "..."`（上記で組み立てた本文）
- `--label "<フェーズ>,重要度:中"` — フェーズは議事の性質に応じて（ヒアリング/見積もり/開発/テスト/納品）。不明ならユーザーに確認
- `--assignee tmyuu`（`gh api user --jq '.login'` で取得）
- `--project "<プロジェクト名>"` — SessionStart の一覧から該当を選ぶ。複数プロジェクトに該当する場合はユーザー確認

Type 設定（org リポジトリのみ）: `updateIssueIssueType` mutation で `Minutes` に設定。

プロジェクトアイテムの Status を **Todo** に明示設定。

### 4. アクションアイテムの子 Issue 化（任意）

- md のアクションアイテムに「子 Issue 化すべき作業」があれば、ユーザー確認のうえ `/new-issue` で子 Task を派生
- 子 Issue を作ったら **Sub-issues API** で親（この Minutes Issue）に紐付け
- 親 Minutes の該当チェックリスト行を `- [x] #子番号 ...` 形式に更新

### 5. 完了報告

- 作成した Issue 番号・URL
- md のリポ相対パス
- 子 Issue 化候補が残っていれば件数

## 禁止事項

- md を編集せずに Issue 化しない（テンプレのまま Issue 化しない）
- `docs/meetings/` 以外の場所に md を置かない
- Issue 本文から md へのリンクを省略しない（md が一次情報）
