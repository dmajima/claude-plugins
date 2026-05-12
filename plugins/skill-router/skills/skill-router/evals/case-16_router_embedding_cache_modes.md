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

```text
/router-embedding-cache --clear
```

```text
/router-embedding-cache --show convert-doc:convert-pdf
```

## 期待動作

| モード | Phase | 動作 |
|--------|-------|------|
| 統計表示 | 1 | `<base>/embeddings_cache/manifest.json` を Read |
| | 2 | `entries` 件数・モデル別集計・最終生成時刻・vectors サイズを整形 |
| | 3 | manifest schema_version / vectors_sha256 / entries_sha256 整合性も併せて表示 |
| `--clear` | 1 | AskUserQuestion で削除確認（対話モード）|
| | 2 | 承認後 `vectors.npz` + `manifest.json` を削除 |
| | 3 | `models/` 配下の ONNX キャッシュは保持（再 DL コスト回避）|
| `--show <qn>` | 1 | `manifest.json` を Read し `entries[<qn>]` を取得 |
| | 2 | `content_hash` / `model` / `idx` / `generated_at` を表示 |
| | 3 | 該当 entry が無ければ「未生成」と案内 |

## 期待出力

| モード | 出力 |
|--------|------|
| 統計表示 | テーブル形式で entries 数・vector dim・最新 5 件のスキル別 idx を提示 |
| `--clear` | `embedding cache cleared at <base>/embeddings_cache/`、次回 SessionStart で再生成される旨の案内 |
| `--show <qn>` | 4 行のキー・バリュー表示、または「<qn> のキャッシュ entry は存在しません」|

## 分岐の根拠

`commands/router-embedding-cache.md` で定義された 3 モード。スキル `skill-router` が利用者に提示する操作系コマンドの動作分岐を完全カバーする必要があるため、各モードを独立にケース化。

## 関連ケース

- `case-02_status` — `/router-status` の `stats.embedding` 表示部
- `case-11_embedding_cache_hit` — キャッシュ生成側の動作
- `case-14_cache_tamper_failopen` — キャッシュ整合性チェック

## 備考

- 同義表現: 「埋め込みキャッシュ確認」「ベクトルキャッシュをクリア」「<plugin>:<skill> の埋め込みを見せて」
- `--clear` の Windows での実行は PowerShell の `Remove-Item -Force` 相当に展開される（README 参照）
- `--show` で指定する `qualified_name` は `<plugin-name>:<skill-name>` 形式
