# case-18 router-embedding-cache --show single skill

`/router-embedding-cache --show <qualified_name>` で 1 スキル分の詳細（`content_hash` / `model` / `idx` / `generated_at`）を表示することを確認する正例。引数完全指定のため非対話モード相当。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "/router-embedding-cache --show convert-doc:convert-pdf" |
| 既存状態 | `embedding.enabled=true`、`<base>/embeddings_cache/manifest.json` に `convert-doc:convert-pdf` エントリ存在 |
| モード | 非対話（引数指定）|

## トリガープロンプト

```text
/router-embedding-cache --show convert-doc:convert-pdf
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | コマンド解釈で `--show convert-doc:convert-pdf` を確定 |
| 2 | `<base>/embeddings_cache/manifest.json` を Read |
| 3 | `entries["convert-doc:convert-pdf"]` を取得 |
| 4 | `content_hash` / `model` / `idx` / `generated_at` を 4 行で表示 |
| 5 | 該当エントリが無ければ「`<qn>` のキャッシュ entry は存在しません」と案内 |

## 期待出力

### 正常系（entry 存在）

```text
content_hash: 7f3e9c2b...
model:        sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
idx:          42
generated_at: 2026-05-12T10:23:45+09:00
```

### entry 不在系

```text
convert-doc:convert-pdf のキャッシュ entry は存在しません
（embedding.enabled=true で /router-rebuild を実行してください）
```

## 分岐の根拠

`commands/router-embedding-cache.md` の `--show` モード。スキル個別の埋め込み状態を診断する用途で、`case-16`（全体統計）と相補的な役割を担う（review evals H-F）。

## 関連ケース

- `case-16_router_embedding_cache_modes` — 統計表示モード（対話）
- `case-17_router_embedding_cache_clear_noninteractive` — `--clear` 非対話
- `case-11_embedding_cache_hit` — entry 生成側の動作

## 備考

- `qualified_name` は `<plugin-name>:<skill-name>` 形式（例: `convert-doc:convert-pdf`）
- `content_hash` は SHA-256 hex 64 文字、表示時は先頭 8 文字 + `...` の省略形を推奨
- 副作用なし（読み取り専用）、フェイルオープン
