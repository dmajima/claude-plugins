# case-17 router-embedding-cache --clear non-interactive

`/router-embedding-cache --clear` を非対話モード（確認スキップ）で実行し、`vectors.npz` + `manifest.json` が削除されることを確認する変形ケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "/router-embedding-cache --clear --non-interactive" 相当 |
| 既存状態 | `embedding.enabled=true`、`<base>/embeddings_cache/{vectors.npz, manifest.json}` 存在 |
| モード | 非対話（確認スキップ・自動進行） |

## トリガープロンプト

```text
/router-embedding-cache --clear
```

引数 `--clear` が指定されている時点で非対話モードとして扱う（同 case の対話確認バージョンは `case-16_router_embedding_cache_modes` の備考を参照）。

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | コマンド解釈で `--clear` 引数を確定 |
| 2 | `AskUserQuestion` を発行せず即時実行 |
| 3 | `<base>/embeddings_cache/vectors.npz` を削除 |
| 4 | `<base>/embeddings_cache/manifest.json` を削除 |
| 5 | `<base>/embeddings_cache/models/` 配下の ONNX モデルは保持（再 DL コスト回避）|
| 6 | 結果を 1 行で出力（対話的な補足案内なし） |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | `skill-router embedding cache cleared (vectors.npz + manifest.json)` のみ |
| 副作用 | `<base>/embeddings_cache/vectors.npz` / `manifest.json` 削除、`models/` 保持 |
| ユーザ介入 | なし（確認・選択ダイアログ非発生） |

## 分岐の根拠

`commands/router-embedding-cache.md` の `--clear` 非対話モード。eval-guide の「対話モードと非対話モード両方をケース化」要件に基づき、`case-09_non_interactive`（`/router-toggle off` 非対話）と同じ構造で本コマンドの非対話モードも独立カバー（review evals H-F）。

## 関連ケース

- `case-16_router_embedding_cache_modes` — 統計表示モード（対話）
- `case-18_router_embedding_cache_show` — `--show` モード
- `case-11_embedding_cache_hit` — 再生成側の動作（clear 後の `/router-rebuild` 想定）

## 備考

- CI 自動化・スクリプトからの呼び出しに耐える挙動を確認
- `--clear` 実行後は次回 SessionStart で `embedding.enabled=true` のとき自動再生成（モデル DL は `models/` 残存により不要）
- 削除失敗時もフェイルオープン原則（exit 0）を維持し、ファイル削除エラーを stderr に出力するに留める
