# case-11 embedding cache hit

`embedding.enabled=true` で 2 回目以降の SessionStart が **キャッシュヒット** によって即時完了し、fastembed 推論が呼ばれない（差分のみ再計算）ことを確認する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "/router-rebuild"（または SessionStart 自動発火） |
| 既存状態 | `embedding.enabled=true`、初回 build 完了済（`<base>/embeddings_cache/vectors.npz` + `manifest.json` あり、`vectors_sha256` 記録済）、スキル本文に変更なし |
| モード | 非対話（自動）|

## トリガープロンプト

```text
/router-rebuild
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `references/scripts/routing/build_index.py` の `build` 実行 |
| 2 | `embedding_enrich.ensure_skill_vectors` で各スキルの `content_hash` を計算 |
| 3 | `manifest.json` の既存 entry と `(content_hash, model)` が一致 → 再ベクトル化スキップ |
| 4 | 既存 `vectors.npz` を `expected_sha256` 検証付きで `load_vectors` 経由再利用 |
| 5 | `index.json` を上書き、`stats.embedding.skills_vectorised` は既存件数と同じ |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | `index.json` 末尾の `stats` 抜粋（`build_duration_ms` が初回より顕著に小さい） |
| 副作用 | `vectors.npz` / `manifest.json` の再書き出しされるが `entries[].content_hash` と `idx` の対応は不変（`generated_at` と `vectors_sha256` は毎回更新される） |
| 計測値 | 2 回目の `build_duration_ms` が 1 回目の 1/100 程度（モデル推論をスキップしているため）|
| 失敗時 | `<base>/error.log` に `traceback.format_exc` を `mask_secrets` 経由で記録、フェイルオープン |

## 分岐の根拠

`references/scripts/routing/embedding_enrich.py` の `ensure_skill_vectors` 内で `content_hash` ベースのキャッシュ判定を行う。差分更新ロジックの正常動作を担保するため、SessionStart の hot path の最適化が崩れていないことを検証する分岐。

## 関連ケース

- `case-01_rebuild` — `/router-rebuild` の基本動作
- `case-12_embedding_boost_reorder` — キャッシュされたベクトルを使ったブースト動作
- `case-14_cache_tamper_failopen` — `vectors_sha256` 不一致時のフェイルオープン

## 備考

- 同義表現として「インデックス再生成」「埋め込み更新」「ベクトル更新」もカバー
- スキル本文（`description` / `use_when` / `evals.prompt` 等）が変わるとそのスキルだけ再ベクトル化され、他はキャッシュ再利用
