# case-10 fail open

`route.py` / `build_index.py` がエラーで失敗した際、フェイルオープン原則（exit 0 透過）を遵守し、`error.log` 書き込みのみで処理を継続する負例ケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | （フック起動。発話は任意。本ケースでは `何かファイルを開いて` 等を想定） |
| 既存状態 | `<base>/index.json` が不正 JSON / `<base>/inverted_index.json` が破損 / `<base>/config.json` が壊れている等の異常状態 |
| モード | 自動（UserPromptSubmit フック） |

## トリガープロンプト

```text
何かファイルを開いて
```

（フック自動発火のため、プロンプト内容は本ケースでは重要ではない）

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `route.py` が `index.json` ロードを試行 |
| 2 | `json.JSONDecodeError` / `OSError` を捕捉し `{}` を返す |
| 3 | `select_candidates` で 0 件となり `route` が None を返す |
| 4 | `additionalContext` を出力せず exit 0 |
| 5 | 重大な例外時は `<base>/error.log` に traceback を書き込み、それでも exit 0 |

## 期待出力

| ケース | 提示内容 |
|-------|---------|
| index.json 破損 / 不正 JSON | サイレントに空インデックスへフォールバック、`additionalContext` 出力なし |
| inverted_index.json 不正 | 同上、ユーザ応答は通常通り進行 |
| 致命的例外 | `<base>/error.log` に `=== <iso8601> route ===` ヘッダ + traceback、ユーザ応答は通常通り進行 |
| 副作用 | フックがブロックしない（プロンプト送信が成功する） |

## 分岐の根拠

`references/scripts/lib/route.py` と `build_index.py` の `main` の `try/except` フェイルオープン構造、および `references/scripts/hooks/route_prompt.sh` の「Bash 側で JSON パースしない」原則。ルーティング処理は補助機能でありユーザの本来作業をブロックしてはならないため、すべての例外パスで exit 0 を貫く。

## 関連ケース

- `case-04_skip_negative` — 正常系のスコアリング動作
- `references/research/s2_hook_concat.py` — 複数フック additionalContext 競合時の挙動

## 備考

- 検証方法: `<base>/index.json` を意図的に不正 JSON へ書き換えてプロンプトを送信し、`<base>/error.log` の有無と通常応答が継続することを確認
- 検証スクリプト例: `printf 'broken' > <base>/index.json` 後にプロンプト送信、復旧は `/router-rebuild`
- `build_index.py` 側の fail-open は `case-01_rebuild` の「失敗時」セクションに記載済み
- 旧 `index.pkl` は廃止済み（pickle.load の RCE 経路回避、`build_index.py` モジュール docstring 参照）
