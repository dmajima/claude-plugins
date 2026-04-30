# Case 06: 非対話モード + 命名衝突 → fail-closed エラー終了

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新しい `/extension` コマンドを作って（自動）" |
| 引数 | `extension --description "..." --placement plugins/dev-toolkit --non-interactive` |
| フラグ | `--non-interactive` |
| 既存状態 | `plugins/dev-toolkit/commands/extension.md` **既存**（同名コマンド衝突）|

## 期待動作

### Phase 1: モード判定 + 命名衝突検出

`--non-interactive` 検出 → 非対話モード（対話確認なし）。
配置先 `plugins/dev-toolkit/commands/extension.md` の存在を確認 → **衝突検出**。

### Phase 2: fail-closed エラー終了

非対話モードでは `AskUserQuestion` による上書き許可確認が成立しないため、即時エラー終了:

```text
[command-toolkit] Error: Naming collision detected (non-interactive mode).

Target: plugins/dev-toolkit/commands/extension.md (already exists)

Non-interactive mode does not support overwrite confirmation. Either:
1. Remove the existing file before re-running
2. Use a different command name (--name <new>)
3. Run in interactive mode for AskUserQuestion-based overwrite/rename selection
```

`exit 1` で終了。**既存ファイルは無傷で保持**（中途半端な上書きを避ける）。

### Phase 3: 引き渡し（処理停止）

| 項目 | 動作 |
|-----|------|
| 既存ファイル | 無変更（保護） |
| 新規ファイル生成 | なし |
| 終了コード | 1 |
| ユーザ対話 | 発生しない |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | なし |
| 標準エラー出力 | 命名衝突エラー + 解決方法 3 案内 |
| 終了状態 | 失敗（exit 1）|

## 分岐の根拠

`--non-interactive` + 命名衝突 → 対話確認が成立しないため fail-closed。
case-04（対話モード + 命名衝突）の AskUserQuestion 4 択提示と対称な同値分割の対称ペア。

## 関連ケース

- `case-04_naming_collision.md`（対話モード + 命名衝突、選択肢提示）
- `case-05_non_interactive.md`（非対話モード、衝突なしの正常生成）
