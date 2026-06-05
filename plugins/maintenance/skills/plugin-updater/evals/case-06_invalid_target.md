# Case 06: 不正な target 値（A-0-1 バリデーション失敗）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` に不正な target 値を渡した場合、または直接スキル起動で不正値を指定した場合 |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `foo`（ホワイトリスト外） |
| 既存状態 | 任意 |

## 期待動作

### Phase A-0-1: 引数バリデーション（失敗）
- `target` が `all` / `current-project` のいずれにも一致しないことを検出
- `references/output-formats.md` の「エラーメッセージ集約 → 不正な target 値」セクションに
  定義された SSOT フォーマットでエラーメッセージを出力:

```text
エラー: 不正な target 値 "foo" が指定されました。有効な値は all / current-project です。
```

- Phase A 以降の処理は行わず即終了

### Phase A〜G: 実行されない
- CLI 呼び出しなし
- 設定ファイルの Read なし

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | なし |
| 標準出力（要約） | SSOT エラーフォーマット（`output-formats.md` 参照）。「不正な target 値 "foo" が指定されました。有効な値は all / current-project です。」 |
| 終了状態 | エラー終了（exit ≠ 0） |

## 分岐の根拠

このケースが分岐するトリガーは `target` 値がホワイトリスト外（`all` / `current-project` 以外） である。

`/update-all` / `/update` コマンド側でも同等の検証が行われるが、スキル側でも fail-closed で
検証する（コマンド経由でなく直接 Skill 起動された場合の防御。ADR-PU-014 参照）。

## 関連ケース

- `case-01_dry_run.md`〜`case-05_target_all.md`（正常な target 値）
- `case-07_cli_missing.md`（A-0-2 で失敗）
- ADR-PU-015: `target` パラメータの導入（有効値の定義）