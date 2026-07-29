# case-13 embedding disabled (default no-op)

`embedding.enabled=false`（既定）でヒューリスティック専用挙動が維持されること、`vectors.npz` が **生成されない** ことを確認する後方互換性の正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "/router-rebuild" + 任意プロンプト |
| 既存状態 | `<venv-base>/config.json` で `embedding.enabled` 未指定または `false`（既定）、`<base>/embeddings_cache/` 不在 |
| モード | 非対話（自動）|

## トリガープロンプト

```text
/router-rebuild
```

その後、任意の自然言語プロンプトを送信:

```text
HTML に変換したい
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `build_index.build` が `embedding_enrich.ensure_skill_vectors` を呼ぶ |
| 2 | `EmbeddingConfig.enabled=False` のため早期 return（`({}, None)`） |
| 3 | `vectors.npz` / `manifest.json` ともに生成されない |
| 4 | `index.json` の `stats.embedding.enabled` は `false` |
| 5 | UserPromptSubmit でも `route.py` の embedding ブースト経路が `embedding_cfg.enabled` で skip |
| 6 | `route_decisions.jsonl` の `embedding_used` は `false` |
| 7 | SessionStart の `ensure` が `venv_required`（`embedding.enabled` かつ有効依存）で false と判定し、venv を構築せず即 return する |
| 8 | `python-bin` はシステム Python を返し、フックは標準ライブラリのみで動作する |

## 期待出力

| 出力 | 内容 |
|-----|------|
| `index.json` | `stats.embedding.enabled=false`、`stats.embedding.skills_vectorised=0` |
| `embeddings_cache/` | ディレクトリ自体が存在しない（または空） |
| `route_decisions.jsonl` | 各行に `"embedding_used": false` |
| `route.log` | `embedding=off` の行 |
| `<venv-base>/.venv` | 生成されない（pip が一度も起動しない。ダウンロード・ディスク消費ともに発生しない） |
| `<venv-base>/venv-construct.log` | 生成されない（構築を試みないため） |

## 分岐の根拠

`references/scripts/routing/build_index.py` の `embedding_active` 判定および `route.py` の `if embedding_cfg.enabled and rows:` ガード。`embedding.enabled=false`（既定）でヒューリスティック専用の挙動を維持する契約を担保する分岐。

## 関連ケース

- `case-12_embedding_boost_reorder` — `embedding.enabled=true` 時の挙動（裏返し）
- `case-01_rebuild` — `/router-rebuild` 基本動作

## 備考

- `config.json` を編集しない限り、追加コスト・追加副作用は発生しない。venv も構築されないため、依存パッケージのダウンロード（約 650 MB）もディスク占有も生じない
- `EmbeddingConfig.from_dict({})` の defaults で `enabled=False` が保証される
