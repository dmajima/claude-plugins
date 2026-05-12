# case-16 /router-embedding-cache 3 modes

`/router-embedding-cache` コマンドの 3 つのモード（統計表示 / `--clear` / `--show <qualified_name>`）が正しく動作することを確認するコマンドカバレッジケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "/router-embedding-cache" / "--clear" / "--show <qn>" の 3 パターン |
| 既存状態 | `embedding.enabled=true`、`vectors.npz` + `manifest.json` 構築済 |
| モード | 統計表示・clear は対話、`--show` は引数指定で非対話 |

## トリガープロンプト

```text
/router-embedding-cache
```

統計表示モード（対話）。`--clear` の非対話モードは `case-17_router_embedding_cache_clear_noninteractive` を、`--show` の単一スキル詳細表示は `case-18_router_embedding_cache_show` を参照（B36 で 3 モードを別ケースに分離）。

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `<base>/embeddings_cache/manifest.json` を Read |
| 2 | `entries` 件数・モデル別集計・最終生成時刻・vectors サイズを整形 |
| 3 | manifest schema_version / vectors_sha256 / entries_sha256 整合性も併せて表示 |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | テーブル形式で entries 数・vector dim・最新 5 件のスキル別 idx を提示 |
| 副作用 | なし（読み取り専用）|
| 失敗時 | `manifest.json` 不在なら「キャッシュ未生成」を案内、フェイルオープン |

## 分岐の根拠

`commands/router-embedding-cache.md` で定義された統計表示モード。スキル `skill-router` が利用者に提示する操作系コマンドの動作分岐を完全カバーする必要があるため、引数なしの統計表示モードを独立ケースとして担保する。

## 関連ケース

- `case-02_status` — `/router-status` の `stats.embedding` 表示部
- `case-11_embedding_cache_hit` — キャッシュ生成側の動作
- `case-14_cache_tamper_failopen` — キャッシュ整合性チェック
- `case-17_router_embedding_cache_clear_noninteractive` — `--clear` 非対話モード
- `case-18_router_embedding_cache_show` — `--show <qn>` 単一スキル詳細

## 備考

- 同義表現: 「埋め込みキャッシュ確認」「ベクトル状態を見せて」「embedding cache 統計」
- 統計表示モードは引数なしで起動。3 モードのうち最も軽量で副作用ゼロ
