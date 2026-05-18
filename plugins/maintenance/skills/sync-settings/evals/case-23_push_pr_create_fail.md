# Case 23: sync-push PR 作成失敗時のロールバック / 手動案内

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/sync-push --scope global --yes` |
| 引数 | `--Mapping global --Yes` |
| 既存状態 | gh CLI は PATH 上に存在するが、`gh auth status` で未認証 / トークン期限切れ / リポジトリへの書き込み権限不足 |

## 期待動作

### Phase 1〜6: 通常通り完了
- マッピング解決 → repo-push/ fetch + reset → ローカル → repo/ コピー →
- 変更検出 → 新ブランチ作成 → git add → git commit → git push (origin/`<branch>`) **成功**
- 規定ブランチへの復帰 **成功**

### Phase 7: PR 作成（失敗）
- `gh pr create --repo $repo --base $branch --head $newBranch --title <T> --body <B>` を実行
- `$LASTEXITCODE != 0` を検出（gh CLI が認証エラー等で失敗）
- `Write-Warning "PR 作成失敗（gh CLI authentication / repo 権限を確認してください）。"`
- 手動 PR 作成案内を Write-Output:
  - base / head / repo の値を提示
  - gh 出力（マスク済み）を Write-MaskedOutput で表示

### 状態
- リモートには新ブランチが既に push 済み（**残置**）。リモートブランチは削除しない
  （PR 手動作成のため残す設計）
- ローカル repo-push/ は規定ブランチに復帰済み
- スキル全体の終了は exit 0（push 自体は成功）+ PR 未作成の警告

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 新ブランチ | push 済み・リモートに残存 |
| ローカル状態 | 規定ブランチに復帰、スキル起動前と同等 |
| 標準出力（要約） | "PR 作成失敗" warning + 手動作成案内 + base/head/repo |
| 終了状態 | exit 0（push 成功・PR は手動対応） |

## 分岐の根拠

このケースが分岐するトリガーは gh CLI 存在 + `gh pr create` 失敗 である。

サブパス:
- A: gh CLI 不在 → 既存 case-18 でカバー（PR 作成スキップ）
- B: gh CLI 存在 + `--no-pr` 指定 → 既存 case-18 でカバー
- **C: gh CLI 存在 + 認証エラー等で失敗 → 本ケース（case-23）**

## 設計意図

PR 作成は push 完了後の最終ステップだが、認証期限切れ等で頻発する失敗パスである。
push 自体は成功しているため、リモートにブランチを残し（再 push の重複を避ける）、
ユーザに手動 PR 作成方法を案内する設計が安全側。

本ケースは push 不可逆操作の **後** のロールバック耐性を独立して検証する。

## 関連ケース

- `case-18_push_basic.md`（push 基本動作 + PR 成功）
- `case-22_push_without_yes_cancel.md`（--Yes なしの安全停止）
- safety.md 節 8.6 PR 作成の明示
