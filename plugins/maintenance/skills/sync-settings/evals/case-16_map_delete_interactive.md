# Case 16: `/sync-map-delete` 対話モード（引数なし・2 段階確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/sync-map-delete" |
| 引数（$ARGUMENTS） | 空文字 |
| 既存状態 | global + カレントディレクトリの project マッピングあり |

## 期待動作

### Phase 1: 現状表示
- `sync-mappings.ps1 -Action list` で現在のマッピング状況をユーザに提示

### Phase 2: Step 1 AskUserQuestion（削除対象選択）

```text
options:
  - 「カレントディレクトリの project マッピング」
  - 「global マッピング」
  - 「キャンセル」
```

Other（Type something）で他の project パス（絶対パス）を入力可能。

### Phase 3: Step 2 AskUserQuestion（削除最終確認）

Step 1 で「削除対象」が選ばれた場合のみ発火（「キャンセル」選択時は終了）:

```text
options:
  - 「削除する」
  - 「キャンセル」
```

### Phase 4: スクリプト実行

「削除する」が選ばれた場合のみ `sync-mappings.ps1 -Action delete -Scope <scope> [-ProjectPath <path>] -Force` を実行。

### Phase 5: 完了報告

`-Action list` で更新後の状態を表示してユーザに完了報告。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| AskUserQuestion 発火回数 | 1〜2 回（Step 1 で「キャンセル」なら 1 回、最終確認まで進めば 2 回）|
| ファイル変更 | 「削除する」確定時のみ `sync-mappings.json` から該当マッピング削除 |
| 標準出力 | `[deleted] <scope> マッピングを削除しました` または `(キャンセル)` |
| 終了状態 | 成功（exit 0）|

## 分岐の根拠

このケースが分岐するトリガーは `$ARGUMENTS` が空文字 である。

## 安全装置

- **2 段階確認**: 削除対象選択 → 削除最終確認の 2 段階で誤削除防止
- スクリプト側で `-Force` フラグ必須化（誤呼び出し防止）
- Step 1 / Step 2 のいずれでも「キャンセル」可能

## 関連ケース

- `case-13_map_set_interactive.md`（対話設定）
- `case-15_map_list.md`（一覧表示）
- 非対話削除（引数: `--scope global --force` 等）: スクリプト直接実行で対応（暗黙ケース）
