# Case 08: 非対話モード + 二段フラグでファイル本体含む削除

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`legacy-plugin` を完全削除（自動）" |
| 引数 | `--non-interactive --remove-plugin legacy-plugin --also-delete-files --confirm-destructive` |
| フラグ | `--non-interactive` + `--remove-plugin` + `--also-delete-files` + `--confirm-destructive` |
| 既存状態 | `marketplace.json` に `legacy-plugin` エントリ存在、`plugins/legacy-plugin/` 実体あり |

## 期待動作

### Phase 1: モード判定 + フラグ検証

`--non-interactive` 検出 → 非対話モード。
削除モード判定: `--remove-plugin` 検出。
**ファイル本体削除フラグ検証**:

| フラグ組み合わせ | 動作 |
|---------------|------|
| `--also-delete-files` 単独 | エラー終了（`--confirm-destructive` 必須メッセージ） |
| `--also-delete-files` + `--confirm-destructive` | 二段フラグ揃い → ファイル本体含む完全削除を実行 |

本ケースは二段フラグ揃いのため続行。

### Phase 2: エントリ削除 + ファイル本体削除（二段フラグガード通過）

| 操作 | 動作 |
|-----|------|
| `marketplace.json` の `plugins[]` から `legacy-plugin` エントリ削除 | 実行 |
| マーケットプレイス README のテーブル該当行削除 | 実行（ADR-019 同期） |
| `plugins/legacy-plugin/` ディレクトリ削除（`rm -rf` 相当） | 実行（最も破壊的） |

非対話モードでも対話確認は行わないが、**ログに警告を必ず記録**:

```text
[marketplace-toolkit] WARNING: Destructive deletion executed (non-interactive mode).
  Target: legacy-plugin
  Removed: marketplace.json entry, README table row, plugins/legacy-plugin/ (recursive)
  Confirmation: --confirm-destructive flag was provided.
```

### Phase 3: 検証

| 項目 | 動作 |
|-----|------|
| `marketplace.json` から `legacy-plugin` 不在 | 必須 |
| README テーブル該当行不在 | 必須 |
| `plugins/legacy-plugin/` 不在 | 必須 |
| JSON valid | 必須 |

### Phase 4: 引き渡し

```text
legacy-plugin を完全削除しました（非対話モード）。

削除内容:
- marketplace.json: plugins[] から legacy-plugin を削除
- README.md: プラグイン一覧テーブルから該当行を削除
- plugins/legacy-plugin/: ディレクトリ完全削除

次のステップ:
- marketplace-publisher でコミット・push（推奨コミットメッセージ: Remove plugin: legacy-plugin）
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `marketplace.json` / `README.md`（テーブル更新）/ `plugins/legacy-plugin/` 削除 |
| 標準出力 | 削除完了メッセージ + 警告ログ + 次ステップ |
| 終了状態 | 成功 |
| ユーザ対話 | 発生しない |

## 分岐の根拠

`--non-interactive` + `--remove-plugin` + 二段フラグ（`--also-delete-files` + `--confirm-destructive`）揃い → 完全削除を実行。
二段フラグの揃いを **必須要件** とすることで、上位スキル（`marketplace-publisher` のフルオート等）が誤って広範な削除を実行することを防ぐ。

## 関連ケース

- `case-03_remove_plugin.md`（対話モードの削除 + AskUserQuestion 二重確認）
- `case-09_non_interactive_destructive_blocked.md`（二段フラグ不揃い時の fail-closed）
