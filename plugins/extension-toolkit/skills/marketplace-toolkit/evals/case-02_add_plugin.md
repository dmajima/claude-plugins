# Case 02: プラグイン追加 + README 同期

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`marketplace.json` に `dev-toolkit` を追加" |
| 引数 | `--add-plugin dev-toolkit --description "開発支援ツール一式" --source ./plugins/dev-toolkit` |
| フラグ | `--add-plugin` |
| 既存状態 | `marketplace.json` 既存、`dev-toolkit` 未登録 |

## 期待動作

### Phase 1: モード判定

`--add-plugin` 検出 → **プラグイン追加モード**。

### Phase 2: 重複チェック

`marketplace.json` の `plugins[]` をスキャンし、`name == "dev-toolkit"` のエントリ未存在を確認。
重複検出時は「更新モードに切り替えますか？」とユーザ確認。

### Phase 3: プラグイン実体検証

`./plugins/dev-toolkit/.claude-plugin/plugin.json` の存在を確認。`plugin.json` の `name` がディレクトリ名と一致することも確認。

### Phase 4: marketplace.json 編集

`plugins[]` に **アルファベット順** で挿入:

```json
{
  "name": "dev-toolkit",
  "source": "./plugins/dev-toolkit",
  "description": "開発支援ツール一式"
}
```

JSON 整合性検証。

### Phase 5: README 同期（ADR-019 準拠）

[`../references/readme-sync.md`](../references/readme-sync.md) のロジックに従い、`README.md` のプラグイン一覧テーブルを再生成:

- 既存テーブル行 + `dev-toolkit` 行を含む新テーブルを生成
- バージョンは `./plugins/dev-toolkit/.claude-plugin/plugin.json` の `version` を直接転記
- インストールコマンドは `/plugin install dev-toolkit@{marketplace-name}` の固定形式

テーブルのみ置換し、その他のセクション（マーケットプレイスの追加方法・自動更新等）は保持。

### Phase 6: 検証

| 項目 | 動作 |
|-----|------|
| `marketplace.json` JSON valid | 必須 |
| `plugins[]` のソースパスが実在 | 必須 |
| README テーブル行数 = `plugins[]` 件数 | 必須 |
| バージョン列が `plugin.json` と一致 | 必須 |

### Phase 7: 引き渡し

```text
dev-toolkit を marketplace.json に追加し、README を同期しました。

次のステップ:
1. marketplace-publisher で git push + PR 作成
2. ハンドオフ（手動でコミット）

どうしますか？
```

`AskUserQuestion` で接続先を選択。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `marketplace.json`（plugins[] に追加）/ `README.md`（テーブル更新） |
| 標準出力 | 追加完了メッセージ + 同期差分 + 次ステップ提案 |
| 終了状態 | 成功 |

## 分岐の根拠

`--add-plugin` フラグ + 既存 `marketplace.json` あり + 重複なし → 追加モード。

## 関連ケース

- `case-03_remove_plugin.md`（プラグイン削除）
- `case-04_sync_readme_only.md`（README 同期のみ）
- `case-05_duplicate_blocked.md`（重複検出時の阻止）
