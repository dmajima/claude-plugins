# Case 19: --dry-run と --yes 同時指定（dry-run 優先）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "とりあえず dry-run で確認して、もし問題なければ yes も付ける" |
| 引数 | `--Mapping global --DryRun --Yes` |
| 既存状態 | global マッピング設定済み・リモートに差分あり |

## 期待動作

### Phase 1: 引数組み合わせの安全装置
- `--DryRun` と `--Yes` が同時指定されていることを検出
- safety.md 節 6.2 / SKILL.md「重要な制約」に基づき、`--DryRun` を優先
- 内部的に `$Yes = $false` に切り替え
- Write-Warning でユーザに通知:
  > `--DryRun と --Yes を同時指定: --DryRun を優先（実適用は行いません）`

### Phase 2〜4: 通常の dry-run フロー
- Git clone / fetch + reset
- 差分検出
- 差分プレビューを表示
- バックアップは取得しない（dry-run のため）
- `Copy-Item` / `Remove-Item` は呼び出さない

### Phase 5: 終了
- exit 0 で正常終了
- `~/.claude/` 配下に変更なし

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 警告メッセージ | "DryRun を優先（実適用は行いません）" 相当 |
| 変更系操作 | なし（Copy-Item / Remove-Item 呼び出しなし） |
| 標準出力（要約） | "===== 差分検出 =====" + "(dry-run) 実適用は行いません" |
| 終了状態 | 成功（exit 0） |

## 分岐の根拠

このケースが分岐するトリガーは `--DryRun` と `--Yes` の同時指定 である。

## 設計意図

`--Yes` は AskUserQuestion 確認をスキップして実適用に進むフラグ、`--DryRun` は差分プレビューのみの
フラグであり、両者は本来排他的である。利用者が誤って両方指定した場合、より安全な側（dry-run）を
優先することで意図しない実適用を防ぐ。

## 関連ケース

- `case-01_dry_run_first.md`（dry-run のみ）
- `case-04_non_interactive.md`（--yes のみ）
- safety.md 節 6.2 引数組み合わせの安全装置
