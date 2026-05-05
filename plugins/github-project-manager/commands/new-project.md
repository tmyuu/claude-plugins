---
description: "GitHub Project (v2) を新規作成し、現在のリポジトリにリンクする。空リポからのブートストラップ用。"
---

新しい GitHub Project (v2) を作成し、現在のリポジトリにリンクしてください。

## 引数

$ARGUMENTS

引数の解釈:
- 文字列が渡されたら **タイトル** として扱う（例: `/new-project 案件A 開発`）
- `--link <N>` のみが渡された場合は **既存 Project N をリンクするだけ**（作成しない）
- 引数なしならユーザーに「タイトルは？」と確認（デフォルト提案: リポジトリ名）

## 前提と注意

- このコマンドは `guard-project-create.sh` のブロックを **`CLAUDE_NEW_PROJECT_ALLOW=1` 環境変数プレフィックス** で明示的にバイパスする。バイパスは `gh project create` の 1 行限定で使うこと。
- 既に同じ Owner に Project が存在する場合は **そちらに紐付ける選択肢をユーザーに提示**してから新規作成へ進むこと。
- 個人リポジトリ・組織リポジトリどちらでも動作する（`gh repo view --json owner -q .owner.login` で実所有者を取得）。

## 手順

### 1. リポジトリ情報取得

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
get_repo_info  # REPO / OWNER / REPO_NAME がエクスポートされる
```

`gh repo view --json owner --jq '.owner.login'` で **実 owner**（個人 or org）を確認。Project は repo owner と同じスコープに作成するのが原則。

### 2. 既存 Project の確認

SessionStart で注入済みの「プロジェクト」一覧を確認。リポジトリにリンク済み Project (`リポリンク:✓`) があればユーザーに確認:

> 「既に `<title>` (#<N>) がリンクされています。新規作成しますか？それともこの Project に紐付けて続行しますか？」

リンク先候補（リポリンク:✗ の Project）があれば「これらにリンクする選択肢もあります」と案内。

`--link <N>` モードの場合は Step 3 をスキップして Step 4 へ。

### 3. Project 作成

タイトルが未確定ならユーザー確認。デフォルト提案は `<REPO_NAME>`。

```bash
CLAUDE_NEW_PROJECT_ALLOW=1 gh project create \
  --owner "$OWNER" \
  --title "<TITLE>" \
  --format json
```

返却 JSON から `number` と `url` を取得。

### 4. リポジトリリンク

```bash
gh project link <NUMBER> --owner "$OWNER" --repo "$REPO"
```

`gh project link` は `guard-project-create.sh` の対象外なので env prefix は不要。

### 5. Status フィールドの確認

GitHub Projects v2 の **デフォルト Status フィールド** は `Todo / In Progress / Done` で `config/taxonomy.json` の `status.flow` と一致するため、追加の初期化は不要。

念のため確認したい場合:

```bash
gh project field-list <NUMBER> --owner "$OWNER" --format json | jq '.fields[] | select(.name=="Status") | .options[].name'
```

`Todo` / `In Progress` / `Done` が揃っていない場合のみユーザーに知らせる（自動修正はしない、手動 UI 推奨）。

### 6. 完了報告と次アクション案内

以下を端的に報告:

- 作成 / 利用した Project: `<title>` (#<N>) — `<url>`
- リポリンク完了
- 次に推奨するアクション:
  1. `/init-workflow` — `.claude/CLAUDE.md` の整備と Label 同期
  2. `/new-issue` — 最初の Issue を作成（`--project` に今作った Project 番号を指定）

## 禁止事項

- `CLAUDE_NEW_PROJECT_ALLOW=1` を `gh project create` 以外のコマンドに付けない
- 同名 Project が既にリンクされている場合、ユーザーに確認せず新規作成しない
- リポリンクなしで放置しない（リンク失敗時はエラー報告して中断、Project は残す）
- README / CLAUDE.md の編集は行わない（責務は `/init-workflow` に委譲）

## エラーハンドリング

- `gh auth status` 失敗 → 認証を促して中断
- `gh project create` 失敗（権限不足等）→ stderr をそのまま提示し中断
- `gh project link` 失敗 → 作成済み Project の情報は残し、ユーザーに手動リンクの方法を案内（`gh project link <N> --owner <owner> --repo <owner/repo>`）
