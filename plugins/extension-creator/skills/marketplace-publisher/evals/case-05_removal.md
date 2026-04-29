# Case 05: プラグイン削除（明示確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`legacy-plugin` をマーケットプレイスから削除" |
| 引数 | `legacy-plugin --remove` |
| フラグ | `--remove` |
| 既存状態 | `legacy-plugin` が marketplace.json に登録済 |

## 期待動作

### Phase 1: 現状確認

該当エントリを検出。

### Phase 2: 削除確認（明示確認必須）

```text
プラグイン `legacy-plugin` をマーケットプレイスから削除します:

- marketplace.json のエントリ削除
- plugins/legacy-plugin/ ディレクトリ削除（このディレクトリ削除も合わせて行いますか？）

実行しますか？（yes/no）
```

### Phase 3: 確認分岐

| 選択 | 動作 |
|-----|------|
| yes（エントリのみ） | marketplace.json のエントリ削除 |
| yes（ディレクトリも） | エントリ削除 + ディレクトリ削除 |
| no | キャンセル |

### Phase 4: 公開モード確認 + 実行

case-01 と同じ。コミットメッセージは `Remove plugin: legacy-plugin`。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `.claude-plugin/marketplace.json`（エントリ削除）+ 任意で `plugins/legacy-plugin/` 削除 |
| 標準出力 | 削除確認 + 公開ハンドオフ or フルオート |
| 終了状態 | 確認結果により異なる |

## 分岐の根拠

`--remove` フラグ + 既存エントリあり。
