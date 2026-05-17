# Case 06: 不正な --scope 値（A-0-1 バリデーション失敗）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all --scope foo` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `scope` | `foo`（ホワイトリスト外） |
| 既存状態 | 任意 |

## 期待動作

### Phase A-0-1: 引数バリデーション（失敗）
- `scope` が `user` / `project` / `local` / `all` のいずれにも一致しないことを検出
- `references/output-formats.md` の「エラーメッセージ集約 → 不正な scope 値」セクションに
  定義された SSOT フォーマットでエラーメッセージを出力
- Phase A 以降の処理は行わず即終了

### Phase A〜G: 実行されない
- CLI 呼び出しなし
- 設定ファイルの Read なし

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | なし |
| 標準出力（要約） | SSOT エラーフォーマット（`output-formats.md` 参照）。許容値リストを含む |
| 終了状態 | エラー終了（exit ≠ 0） |

## 分岐の根拠

このケースが分岐するトリガーは `scope` 値がホワイトリスト外 である。

`/update-all` コマンド側でも同等の検証が行われるが、スキル側でも fail-closed で
検証する（コマンド経由でなく直接 Skill 起動された場合の防御）。

## 関連ケース

- `case-01_dry_run.md`〜`case-05_scope_all.md`（正常な scope 値）
- `case-07_cli_missing.md`（A-0-2 で失敗）
