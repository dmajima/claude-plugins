# Case 15: `/sync-map-list` 一覧表示

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/sync-map-list" or "/sync-map-list --show" |
| 引数 | なし（`list`）または `--show`（`show`）|
| 既存状態 | マッピングの有無は問わない |

## 期待動作

### Phase 1: アクション判定
- 引数 `--show` あり → `-Action show`
- 引数なし → `-Action list`

### Phase 2: スクリプト実行
- `sync-mappings.ps1 -Action <list|show>` を実行
- 標準出力をユーザに提示

## 期待出力（list）

| 項目 | 期待値 |
|-----|-------|
| マッピング不在 | 「（マッピングなし）」「件数: 0 件」 |
| global のみ | `[global] <url> (branch=<branch>)` + 件数: 1 件 |
| project のみ | `[project: <path>] <url> (branch=<branch>)` + 件数: 1 件 |
| 両方 | 上記 2 行 + 件数: 2 件以上 |

## 期待出力（show）

| 項目 | 期待値 |
|-----|-------|
| 各マッピング | remote_repo / remote_branch / targets / last_sync_at をフィールド単位で表示 |
| Config file path | 表示される |
| version | `version: 2` 表示 |

## 分岐の根拠

このケースが分岐するトリガーは 引数 `--show` の有無 である。

## 関連ケース

- `case-13_map_set_interactive.md`（対話設定）
- `case-14_map_set_non_interactive.md`（非対話設定）
