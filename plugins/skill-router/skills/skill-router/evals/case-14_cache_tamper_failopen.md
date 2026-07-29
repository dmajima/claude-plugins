# case-14 cache tamper fail-open

`<base>/embeddings_cache/vectors.npz` が改竄された状態で UserPromptSubmit が発火した際に、SHA-256 検証が不一致を検出してヒューリスティック専用に **静かにフォールバック** することを確認するエラー系。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 任意の自然言語プロンプト |
| 既存状態 | `embedding.enabled=true`、`vectors.npz` + `manifest.json` 構築済、その後 `vectors.npz` を 1 バイト改竄 |
| モード | 自動（フック発火）|

## トリガープロンプト

```text
HTML に変換したい
```

事前準備:

```bash
# 検証用に vectors.npz を意図的に破壊
printf '\x00' >> "<base>/embeddings_cache/vectors.npz"
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `route.route` が `embedding_enrich.load_vectors_sha256_from_manifest(base)` で expected_sha256 取得 |
| 2 | `embedding_enrich.load_vectors(base, expected_sha256=...)` が改竄ファイルの SHA-256 を再計算 |
| 3 | manifest 記録値と不一致 → `None` 返却 |
| 4 | `route.py` で `matrix is None` → `embedding_route.boost_rows` 呼出をスキップ |
| 5 | ヒューリスティック単独で tier 判定し additionalContext を組み立て（または low なら未注入） |
| 6 | `route_decisions.jsonl` に `embedding_used: false` で記録 |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | 通常通り `additionalContext` JSON または無出力（low 帯） |
| 副作用 | プロセス継続、例外伝播なし |
| `route_decisions.jsonl` | 改竄後の決定行で `embedding_used: false` |
| `route.log` | 通常の決定ログ（embedding=off と記録）|

## 分岐の根拠

`references/scripts/routing/embedding_enrich.py` の `load_vectors(expected_sha256=...)` における SHA-256 検証 + `route.py` の `embedding_route.boost_rows` への通知。攻撃者が `vectors.npz` だけ書き換えてもルーティング誘導が成立しないことを担保するセキュリティ分岐（CWE-345 緩和）。

## 関連ケース

- `case-10_fail_open` — index.json 破損時のフェイルオープン
- `case-11_embedding_cache_hit` — 正常時のキャッシュ再利用（裏返し）

## 備考

- `manifest.json` 自体の改竄は `entries_sha256` 自己整合チェックで検出（攻撃者が両方を整合的に書き換えると突破可能、防御は best-effort）
- 改竄検出後は `/router-rebuild` で再生成を案内するのが運用上の対処
- POSIX 環境では `vectors.npz` / `manifest.json` を `0o600` で保存して改竄を物理的にも抑止
