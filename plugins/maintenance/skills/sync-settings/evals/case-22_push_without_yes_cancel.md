# Case 22: sync-push の --Yes なし / 対話確認キャンセル分岐

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/sync-push --scope global` |
| 引数 | `--Mapping global`（`--Yes` / `--DryRun` いずれも未指定）|
| 既存状態 | global マッピング設定済み・リモートに差分あり |

## 期待動作

### Phase 1: マッピング解決 + 検証
- global マッピング取得
- 引数バリデーション・除外チェック通過

### Phase 2: clone 領域準備
- 既存 repo-push/ を fetch + checkout + reset

### Phase 3: ローカル → repo/ コピー
- targets を除外フィルタ + reparse 安全列挙でコピー

### Phase 4: git status で変更検出
- 差分あり（cmd 出力で `M ...` / `?? ...` 等を確認）

### Phase 5: Yes フラグなしの分岐
- `--Yes` 未指定のため push を実行せず、以下のメッセージを出力:

```text
実 push するには -Yes フラグを付けて再実行してください（AskUserQuestion 経由推奨）。
```

- `Pop-Location` で REPO_DIR から脱出して exit 0

### 対話モード（呼び出し側）からの追加確認
コマンド `/sync-push` 対話モードは `--Yes` なしで起動された場合、Step 1〜3 を経て
最終的に `--Yes` を付けて再実行する形に変換する設計（commands/sync-push.md 参照）。
本ケースはスクリプト単独実行時の安全装置を検証する。

### キャンセル相当の挙動
コマンド対話モードでユーザが「キャンセル」を選択した場合は、スクリプトを起動せずに
exit 0 で終了する。本ケースはスクリプト起動後に `--Yes` なしで停止する挙動を確認する。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| git add / commit / push 呼び出し | なし |
| ブランチ作成 | なし |
| 標準出力（要約） | "実 push するには -Yes フラグを付けて再実行してください" |
| 終了状態 | 成功（exit 0、push は実施せず） |

## 分岐の根拠

このケースが分岐するトリガーは `--Yes` 未指定 + 差分あり である。

## 設計意図

`/sync-push` は不可逆操作（リモートへの push + PR 作成）のため、AI 主導の意図しない
実行を防ぐ多層安全装置として `--Yes` 必須化されている。本ケースは安全装置の
独立した動作確認として固定する。

## 関連ケース

- `case-18_push_basic.md`（--Yes 指定ありの正常系）
- `case-19_dry_run_overrides_yes.md`（--DryRun 優先）
- safety.md 節 8 push 方向の安全装置
