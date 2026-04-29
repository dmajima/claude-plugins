# Case 01: 新規登録（ハンドオフ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`extension-creator` プラグインを公開" |
| 引数 | `extension-creator` |
| フラグ | なし |
| 既存状態 | プラグイン実体あり、marketplace.json に未登録 |

## 期待動作

### Phase 1: 現状確認

`.claude-plugin/marketplace.json` を Read。`extension-creator` が未登録を確認。

### Phase 2: プラグイン実体検証

`plugins/extension-creator/.claude-plugin/plugin.json` 存在 + name 一致を確認。

### Phase 3: 重複チェック

`marketplace.json` の既存 `plugins[]` を比較。重複なし → 新規登録続行。

### Phase 4: marketplace.json 更新

`plugins[]` に新エントリ追加（アルファベット順維持）。

### Phase 5: 公開モード確認

ユーザに「ハンドオフ / フルオート」を選択させる。「ハンドオフ」選択時は次へ。

### Phase 6: ハンドオフ提示

変更ファイル一覧 + 差分 + 推奨コミットメッセージ + 次のコマンド + PR 作成 URL を提示。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `.claude-plugin/marketplace.json` |
| 標準出力 | ハンドオフフォーマット（git コマンド + PR 作成 URL） |
| 終了状態 | 完了（コミット以降はユーザ実施） |

## 分岐の根拠

重複なし + ハンドオフモード選択。
