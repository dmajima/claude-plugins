# Case 09: 非対話モード + 二段フラグ不揃い時の fail-closed

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`legacy-plugin` のファイル本体も削除（自動）" |
| 引数 | `--non-interactive --remove-plugin legacy-plugin --also-delete-files`（**`--confirm-destructive` なし**） |
| フラグ | `--non-interactive` + `--remove-plugin` + `--also-delete-files`（二段フラグ片方のみ） |
| 既存状態 | `marketplace.json` に `legacy-plugin` エントリ存在、`plugins/legacy-plugin/` 実体あり |

## 期待動作

### Phase 1: モード判定 + フラグ検証

`--non-interactive` 検出 → 非対話モード。
削除モード判定: `--remove-plugin` 検出。
**ファイル本体削除フラグ検証**: `--also-delete-files` あり、`--confirm-destructive` **なし** → **二段フラグ不揃い**。

### Phase 2: fail-closed エラー終了

```text
[marketplace-toolkit] Error: Destructive flag combination requires confirmation.

Detected: --also-delete-files (without --confirm-destructive)

To execute file body deletion in non-interactive mode, both flags are required:
  --also-delete-files --confirm-destructive

To delete only marketplace.json + README entries (file body kept):
  Drop --also-delete-files

Aborting. No changes have been made.
```

ファイル本体削除は **行わない**。`marketplace.json` の編集も **行わない**（中途半端な状態を作らないため）。

### Phase 3: 引き渡し（処理停止）

| 項目 | 動作 |
|-----|------|
| `marketplace.json` 変更 | なし |
| README 変更 | なし |
| `plugins/legacy-plugin/` 削除 | なし |
| 終了コード | 1 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | なし |
| 標準エラー出力 | 二段フラグ必須エラー + 解決方法（フラグ組み合わせ案内）|
| 終了状態 | 失敗（exit 1）|

## 分岐の根拠

`--also-delete-files` 単独（`--confirm-destructive` なし）→ fail-closed。
意図しない破壊的操作の自動実行を防ぐ二段ガード設計（[`../references/operations.md`](../references/operations.md) の「削除操作の安全装置」参照）。

## 関連ケース

- `case-08_non_interactive_destructive_removal.md`（二段フラグ揃いの正常実行）
- `case-03_remove_plugin.md`（対話モードの削除 + AskUserQuestion 二重確認）
