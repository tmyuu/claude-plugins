---
description: "GitHub Issue のステータス変更、アクションアイテム更新、子Issueクローズ連動を行う"
---

issue-manager エージェントに委譲して、以下の Issue を更新してください。

## 更新内容

$ARGUMENTS

## 対応パターン

### ステータス変更
- GitHub Projects v2 のステータスを変更（Todo → In Progress → Done）
- `gh api graphql` で ProjectV2 のステータスフィールドを更新

### アクションアイテム更新
- Issue 本文のチェックリスト `- [ ]` → `- [x]` を更新
- `gh issue edit N --body "..."` で本文全体を更新

### 子 Issue クローズ
1. 子 Issue をクローズ（`gh issue close N`）
2. 親 Issue のアクションアイテムで該当行を `- [x]` に更新
3. 親の全アクションアイテムがチェック済みなら、親のクローズをユーザーに提案

### Issue クローズ
- PR マージで自動クローズが望ましい（`Closes #N`）
- 手動クローズはユーザーに確認してから実行
- クローズ前に全アクションアイテムのチェック状態を確認
