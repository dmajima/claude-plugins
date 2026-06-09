# Case 07: プラグイン更新（--update-plugin モード）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`marketplace.json` の `dev-toolkit` description を更新" |
| 引数 | `--update-plugin dev-toolkit --description "新しい説明"` |
| フラグ | `--update-plugin` |
| 既存状態 | `marketplace.json` に `dev-toolkit` エントリ存在 |

## 期待動作

### Phase 1: モード判定 + エントリ特定

`--update-plugin` 検出 → **プラグイン更新モード**。
`marketplace.json` から `dev-toolkit` エントリを特定。未存在の場合はエラー終了し、`--add-plugin` への切替をユーザに案内する。

### Phase 2: 更新フィールド検証

引数で受け取ったフィールド（`--description` / `--source` のいずれか）の妥当性を検証:

| フィールド | 検証 |
|----------|------|
| `--description` | 1〜200 文字、`§` 記号不可 |
| `--source` | `./plugins/` プレフィックス必須、パストラバーサル不可（`assert_source_safe`） |

### Phase 3: marketplace.json 更新

該当エントリの指定フィールドを更新（既存値は上書き）。他フィールドは維持。
JSON 整合性検証（valid + name 一致 + source 実在）。

### Phase 4: README 同期（ADR-019）

[`../references/readme-sync.md`](../references/readme-sync.md) のロジックに従い、リポジトリルート README のプラグイン一覧テーブルを再生成。
バージョン列は各 `plugin.json` から自動取得（更新不要）。description 列のみ反映。

### Phase 5: 検証

| 項目 | 動作 |
|-----|------|
| `marketplace.json` JSON valid | 必須 |
| 更新フィールド以外が無傷 | 必須 |
| README テーブルの該当行が更新 | 必須 |
| `plugins[]` 件数が変わっていない | 必須 |

### Phase 6: 引き渡し

```text
dev-toolkit のエントリを更新し、README を同期しました。

変更内容:
- description: "{古い説明}" → "新しい説明"

次のステップ:
- marketplace-publish で git push + PR 作成
- ハンドオフ
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `marketplace.json`（指定フィールドのみ更新）/ `README.md`（テーブル更新） |
| 標準出力 | 更新完了 + 差分 + 次ステップ |
| 終了状態 | 成功 |

## 分岐の根拠

`--update-plugin` フラグ + 既存エントリあり → 更新モード。
未存在エントリの場合はエラーで `--add-plugin` への切替を案内する。

## 関連ケース

- `case-02_add_plugin.md`（追加）
- `case-04_sync_readme_only.md`（README 同期のみ）
- `case-05_duplicate_blocked.md`（重複検出時の阻止、更新モード切替の選択肢提示）
