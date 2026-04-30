# Case 03: プラグイン削除（明示確認 + ファイル削除選択）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`marketplace.json` から `legacy-toolkit` を削除" |
| 引数 | `--remove-plugin legacy-toolkit` |
| フラグ | `--remove-plugin` |
| 既存状態 | `marketplace.json` に `legacy-toolkit` エントリ存在、`plugins/legacy-toolkit/` 実体あり |

## 期待動作

### Phase 1: モード判定 + エントリ特定

`--remove-plugin` 検出 → **プラグイン削除モード**。
`marketplace.json` から `legacy-toolkit` エントリを特定。

### Phase 2: 明示的確認（fail-closed）

`AskUserQuestion` で必ず確認:

```text
legacy-toolkit をマーケットプレイスから削除します。
この操作は marketplace.json と README の該当行を削除します。
プラグインのファイル本体（plugins/legacy-toolkit/）も削除しますか？

選択肢:
1. marketplace.json + README + ファイル本体を削除
2. marketplace.json + README のみ削除（ファイルは保持、後で手動削除可能）
3. キャンセル
```

選択 3 → 何もせず終了。
選択 2 → ファイル本体保持。
選択 1 → ファイル本体も削除（最も破壊的）。

### Phase 3: marketplace.json から削除

選択 1 または 2 の場合、`plugins[]` から該当エントリを削除。
JSON 整合性検証。

### Phase 4: ファイル本体削除（選択 1 のみ）

`plugins/legacy-toolkit/` を削除（`rm -rf` 相当）。
削除前に再度 `AskUserQuestion` で「実行してよいか？」を確認（二重確認）。

### Phase 5: README 同期

プラグイン一覧テーブルから該当行を削除（[`../references/readme-sync.md`](../references/readme-sync.md) のロジック）。

### Phase 6: 引き渡し

```text
legacy-toolkit を削除しました。

削除内容:
- marketplace.json: plugins[] から legacy-toolkit を削除
- README.md: プラグイン一覧テーブルから該当行を削除
- plugins/legacy-toolkit/: {ファイル本体削除選択時のみ}

次のステップ:
- marketplace-publisher でコミット・push
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `marketplace.json` / `README.md`（テーブル更新）/ `plugins/legacy-toolkit/`（選択 1 時のみ削除） |
| 標準出力 | 削除完了メッセージ + 削除内容詳細 |
| 終了状態 | 成功（または選択 3 でキャンセル） |
| ユーザ確認 | 最低 1 回、ファイル本体削除時は **2 回** |

## 分岐の根拠

`--remove-plugin` フラグ + 該当エントリ存在 → 削除モード。
**破壊的操作のため、明示確認なしでは実行しない**（fail-closed）。

## 関連ケース

- `case-02_add_plugin.md`（追加）
- `case-04_sync_readme_only.md`（README 同期のみ）
