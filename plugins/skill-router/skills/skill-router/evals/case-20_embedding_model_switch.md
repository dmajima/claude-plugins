# case-20 embedding model switch invalidation

`config.json` の `embedding.model` を別モデルに変更した状態で SessionStart が発火した際、既存キャッシュが **モデル不一致で無効化** され全スキルが再ベクトル化されることを確認する変形ケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "/router-rebuild" |
| 既存状態 | `embedding.enabled=true`、`<base>/embeddings_cache/manifest.json` の全エントリが `model=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`、`config.json` を `embedding.model=BAAI/bge-small-en-v1.5` に書き換え |
| モード | 非対話（自動）|

## トリガープロンプト

```text
/router-rebuild
```

事前準備:

```bash
# config.json を書き換える
cat > <base>/config.json <<'JSON'
{
  "embedding": {
    "enabled": true,
    "model": "BAAI/bge-small-en-v1.5"
  }
}
JSON
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `embedding_enrich.ensure_skill_vectors()` がスキル毎に `content_hash` を計算 |
| 2 | `manifest.json` の既存エントリと `(content_hash, model)` を比較 |
| 3 | `content_hash` は一致するが `model` が異なるため **全エントリがキャッシュミス判定** |
| 4 | `BAAI/bge-small-en-v1.5` モデルを HF ハブから DL（初回時のみ） |
| 5 | 全スキルを新モデルで再ベクトル化 |
| 6 | `vectors.npz` + `manifest.json` を上書き、`vectors_sha256` / `entries_sha256` 再記録 |
| 7 | `index.json` の `stats.embedding.model` が新値に更新 |

## 期待出力

| 出力 | 内容 |
|-----|------|
| `index.json` | `stats.embedding.model="BAAI/bge-small-en-v1.5"`、`skills_vectorised` は再ベクトル化されたスキル件数 |
| `manifest.json` | 全エントリの `model` フィールドが新モデル名に更新、`vectors_sha256` も新ベクトル群の SHA に置換 |
| `build_duration_ms` | 初回相当に増加（推論を再実行したため、case-11 のキャッシュヒット時と比べて顕著に大きい）|

## 分岐の根拠

`references/scripts/lib/embedding_enrich.py` の `ensure_skill_vectors` 内の `(content_hash, model)` 複合キーチェック（`test_embedding_enrich.py::test_model_change_invalidates_cache` でユニット保証）。モデル切り替え時のキャッシュ無効化動作を eval として形式化することで、運用者がモデル変更後の挙動を予測可能にする（review evals M-8）。

## 関連ケース

- `case-11_embedding_cache_hit` — 同モデル時のキャッシュヒット（裏返し）
- `case-12_embedding_boost_reorder` — モデル変更後のブースト挙動
- `case-13_embedding_disabled` — `enabled=false` 時の no-op

## 備考

- `BAAI/bge-small-en-v1.5` は英語専用モデル。多言語入力では精度が落ちる点に注意（README で対応プラットフォーム+モデル選定指針を案内）
- モデルファイル群は `<base>/embeddings_cache/models/` 配下に共存可能（`models--BAAI--bge-small-en-v1.5/` と `models--sentence-transformers--paraphrase-multilingual-MiniLM-L12-v2/` が並ぶ）
- 再ベクトル化中も heuristic は動作するため、ユーザ体感の劣化なし
