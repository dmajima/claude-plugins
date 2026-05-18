# Case 20: 非対話モードで --repo / --Mapping 不足エラー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "CI で /sync-pull を非対話実行したい" |
| 引数 | `--Yes --Strategy overwrite`（`--Repo` も `--Mapping` も指定なし） |
| 既存状態 | sync-config.json / sync-mappings.json のいずれにも `last_repo` / global mapping が存在しない |

## 期待動作

### Phase 1: 引数解析
- `--Yes` / `--Strategy overwrite` を確定
- `--Repo` 不在
- `--Mapping` 不在
- `sync-config.json` 不在または `last_repo` フィールド未設定
- `sync-mappings.json` 不在または global マッピング未設定

### Phase 2: 必須項目検証（失敗）
- Repo URL を解決できないことを検出
- 対話モード（AskUserQuestion 等）に進む条件と、非対話モードでの即時エラー終了の条件を判定
- 非対話相当（`--Yes` 指定）のため、対話に進まずエラー終了
- `Write-Error "Repo 引数が必要です（--Repo または sync-config.json）"` を出力
- exit 1 で終了

### Phase 3 以降: 実行されない
- Git clone / fetch なし
- 差分検出なし

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準エラー出力 | "Repo 引数が必要です（--Repo または sync-config.json）" 相当 |
| 標準出力 | 設定解決失敗の旨を案内（`/sync-map-set` 経由でのマッピング設定を推奨）|
| 終了状態 | エラー終了（exit 1） |

## 分岐の根拠

このケースが分岐するトリガーは `--Repo` / `--Mapping` 双方が未指定 + 設定ファイルからも取得不能 である。

## 関連ケース

- `case-04_non_interactive.md`（--Repo 指定ありの正常系）
- `case-09_config_reuse.md`（sync-config.json から last_repo を取得する正常系）
- procedures.md 節 1.3 解決優先順位
