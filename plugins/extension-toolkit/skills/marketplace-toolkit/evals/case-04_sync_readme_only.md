# Case 04: README 同期のみ

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "マーケットプレイス README を最新化" |
| 引数 | `--sync-readme` |
| フラグ | `--sync-readme` |
| 既存状態 | `marketplace.json` あり、各プラグインの `plugin.json` 存在、README は手動更新が古いまま |

## 期待動作

### Phase 1: モード判定

`--sync-readme` 検出 → **README 同期モード**。

### Phase 2: marketplace.json + 各 plugin.json 読込

```python
mp = read_json("./.claude-plugin/marketplace.json")
for entry in mp["plugins"]:
    pj = read_json(f"./{entry['source']}/.claude-plugin/plugin.json")
    versions[entry["name"]] = pj["version"]
```

### Phase 3: テーブル再生成

[`../references/readme-sync.md`](../references/readme-sync.md) のロジックに従い、`README.md` の「## プラグイン一覧」直下のテーブルを完全再生成。

| 列 | 値 |
|---|----|
| プラグイン名 | `marketplace.json` の各エントリ |
| 説明 | `marketplace.json` の `description` |
| バージョン | 各 `plugin.json` の `version`（最新化） |
| インストール | 固定形式 |

### Phase 4: 必須セクション補完

README に必須セクションが欠落している場合、テンプレートから補完:

| 欠落項目 | 補完元 |
|--------|--------|
| マーケットプレイスの追加方法（A: URL / B: ローカル複製）| `templates/marketplace/README.md` |
| 自動更新の有効化 | 同上 |

補完時はユーザに通知（差分提示）。

### Phase 5: 検証

| 項目 | 動作 |
|-----|------|
| テーブル行数 = `plugins[]` 件数 | 必須 |
| バージョン列が `plugin.json` と一致 | 必須 |
| 必須セクション存在 | 必須 |

### Phase 6: 引き渡し

```text
マーケットプレイス README を同期しました。

更新内容:
- プラグイン一覧テーブル: {N} 行を再生成
- バージョン列: {変更プラグイン一覧}
- 補完したセクション: {あれば一覧}

次のステップ:
- 内容を確認後、コミット
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `README.md` |
| 標準出力 | 同期完了 + 差分プレビュー |
| 終了状態 | 成功 |

## 分岐の根拠

`--sync-readme` フラグのみ → README のみ同期、`marketplace.json` 編集なし。

## 関連ケース

- `case-02_add_plugin.md`（追加時に自動同期）
- `case-03_remove_plugin.md`（削除時に自動同期）
