# Case 05: 重複プラグイン追加の阻止

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`marketplace.json` に `extension-toolkit` を追加" |
| 引数 | `--add-plugin extension-toolkit --description "..."` |
| フラグ | `--add-plugin` |
| 既存状態 | `marketplace.json` に **既に `extension-toolkit` エントリが存在** |

## 期待動作

### Phase 1: モード判定 + 重複検査

`--add-plugin` 検出 → 追加モードに入り、`plugins[]` に `name == "extension-toolkit"` が既存。

### Phase 2: ユーザに分岐確認（fail-safe）

```text
extension-toolkit はすでに marketplace.json に登録されています。

選択肢:
1. 既存エントリの description / source を更新する（更新モードへ切り替え）
2. キャンセル（marketplace.json は変更しない）
```

`AskUserQuestion` で確認。

### Phase 3: 選択分岐

| 選択 | 動作 |
|-----|------|
| 1 | 更新モード（case-02 とは別フロー）に切り替え、`description` / `source` を上書き、README 同期 |
| 2 | 何もせず終了 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | 選択 1 → `marketplace.json` + README、選択 2 → なし |
| 標準出力 | 重複検出メッセージ + 選択肢 + 選択結果 |
| 終了状態 | 成功（更新 or キャンセル） |

## 分岐の根拠

追加モード + 重複検出 → **fail-safe**（黙って上書きせず、ユーザに意図確認）。

## 関連ケース

- `case-02_add_plugin.md`（重複なしの正常追加）
