# case-19 air-gapped model DL failure

`embedding.enabled=true` の状態でエアギャップ環境（HuggingFace ハブへの到達性なし）で SessionStart が発火した際に、モデル DL 失敗を **静かにフェイルオープン** し、heuristic 単独に縮退することを確認するエラー系。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "/router-rebuild"（または SessionStart 自動発火） |
| 既存状態 | `embedding.enabled=true`、`<venv-base>/embeddings_cache/models/` にモデル未配置、HF ハブへ HTTPS 接続不可（DNS or HTTP エラー）|
| モード | 非対話（自動）|

## トリガープロンプト

```text
/router-rebuild
```

事前準備（エアギャップ再現）:

```bash
# 検証用に HF ハブへの解決を一時的に無効化（実環境では行わない）
export HF_HUB_OFFLINE=1
# あるいはネットワーク非接続環境で実行
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 0 | venv 未構築の場合、SessionStart の `ensure` が `construct()` を実行し、`pip install` がネットワーク到達不可で失敗する。`<venv-base>/venv-construct.log` に記録され、`<venv-base>/.venv-construct-failed` の `count` が加算される。以降 `python-bin` はシステム Python を返すため `fastembed` は import できない |
| 1 | `build_index.build` 内で `embedding_enrich.ensure_skill_vectors` を呼ぶ |
| 2 | `embedding_client.get_model` が `fastembed.TextEmbedding` を構築試行 |
| 3 | モデル DL 失敗 → 例外発生 |
| 4 | `get_model` の except 節で `None` 返却 |
| 5 | `ensure_skill_vectors` が `({}, None)` を返却 |
| 6 | `build_index.build` の except で WARNING ログを `index.log` に記録（`heuristic-only` に縮退）|
| 7 | `stats.embedding.enabled=false`、`skills_vectorised=0` で `index.json` 書き出し |
| 8 | UserPromptSubmit でも `matrix is None` で `boost_rows` をスキップ |

## 期待出力

| 出力 | 内容 |
|-----|------|
| `index.json` | `stats.embedding.enabled=false`、`stats.embedding.skills_vectorised=0` |
| `index.log` | `indexed skills=... embedding=off` 等の WARNING |
| `error.log` | （任意）`traceback.format_exc` を `mask_secrets` 経由で記録 |
| 副作用 | プロセス継続、例外伝播なし。`vectors.npz` / `manifest.json` 未生成 |
| ユーザ体感 | 通常通り heuristic ベースのルーティング推奨が動作（embedding なしで運用） |

## 分岐の根拠

`references/scripts/routing/embedding_client.py` の `get_model` および `embedding_enrich.ensure_skill_vectors` の例外 → `None` 返却 → `build_index.build` の except 節という多層フェイルオープン経路。エアギャップ環境での運用継続性を担保する分岐（review evals H-F）。

## 関連ケース

- `case-24_diag_prompt_hook_timeout` — 構築失敗のバックオフ（3 回連続失敗で 6 時間抑止）の診断

- `case-13_embedding_disabled` — 設定で明示的に無効化したケース（裏返し）
- `case-14_cache_tamper_failopen` — キャッシュ改竄時のフェイルオープン
- `case-10_fail_open` — index 破損時のフェイルオープン

## 備考

- エアギャップ環境では README「オフライン環境向け（事前配置運用・推奨）」セクションに従い、オンライン環境で取得した `models/` 配下を tar 等で事前配置するのが正攻法
- 本ケースは「事前配置を忘れた」「DNS 障害」等の運用ミスでも動作継続することを担保
- 本ケースは実環境のネットワークを実際に切断するため、CI 自動実行よりは手動検証向き
