# Case 07: claude plugin CLI 不在（A-0-2 失敗）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `scope` | `all` |
| 既存状態 | `claude` コマンドが PATH 上に存在しない、または必要なサブコマンド（`plugin marketplace list` 等）が認識されない |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `mode` / `scope` は正常に確定

### Phase A-0-2: Claude Code CLI 存在チェック（失敗）
- `claude` コマンドの起動 / `--help` のチェックを試みる
- 「コマンドが見つからない」または「期待するサブコマンドが応答しない」を検出
- `references/output-formats.md` の「エラーメッセージ集約 → CLI 不在」セクションの
  SSOT フォーマットでエラーメッセージを出力（インストール案内・公式ドキュメント URL を含む）
- Phase A 以降の処理は行わず即終了

### Phase A〜G: 実行されない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | なし |
| 標準出力（要約） | SSOT エラーフォーマット（CLI インストール案内 + 公式 URL） |
| 終了状態 | エラー終了（exit ≠ 0） |

## 分岐の根拠

このケースが分岐するトリガーは `claude plugin` CLI のサブコマンド検出失敗 である。

## 関連ケース

- `case-06_invalid_scope.md`（A-0-1 で失敗）
- `case-01_dry_run.md`（CLI 存在前提の正常系）
