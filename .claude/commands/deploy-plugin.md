---
description: "[開発中のみ] claude-plugins の最新ファイルを展開先リポジトリに並列コピーする"
---

`.claude/scripts/deploy-plugin.sh $ARGUMENTS` を実行して、claude-plugins の現在の状態を展開先リポジトリに反映してください。

## 注意

これはプラグイン開発中の特別なタスクです。通常のワークフローには組み込まず、**ユーザーが明示的に指示した時のみ** 実行してください。

## 使い方

- 引数なし → 全ファイル展開
- `--list` → 展開先リポジトリ一覧を表示
- ファイル名指定 → 指定ファイルのみ展開

## 将来の削除

開発が落ち着いたら、以下を削除すれば完全に除去できます:
- `.claude/scripts/deploy-plugin.sh`
- `.claude/commands/deploy-plugin.md`（このファイル）

他のファイルに参照は残していないので、副作用なく削除可能です。
