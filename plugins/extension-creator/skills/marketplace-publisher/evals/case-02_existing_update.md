# Case 02: 既存プラグイン更新（description 変更）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`extension-creator` の description を更新" |
| 引数 | `extension-creator --description "新しい説明"` |
| フラグ | なし |
| 既存状態 | `extension-creator` が marketplace.json に登録済 |

## 期待動作

### Phase 1: 現状確認

既存エントリを検出。

### Phase 2: 整合性確認

`plugin.json` の `description` と引数 `--description` が一致するか確認。不一致時はユーザに確認。

### Phase 3: marketplace.json 更新

該当エントリの `description` のみ更新（他フィールドは維持）。

### Phase 4: 公開モード確認 + 実行

case-01 と同じ。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `.claude-plugin/marketplace.json`（description のみ変更） |
| 標準出力 | ハンドオフ or フルオート結果 |
| 終了状態 | 完了 |

## 分岐の根拠

既存エントリあり + 更新指示。
