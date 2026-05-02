# case-10 fail open

`route.py` / `build_index.py` がエラーで失敗した際、フェイルオープン原則（exit 0 透過）を遵守し、`error.log` 書き込みのみで処理を継続する負例ケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | （フック起動。発話は任意。本ケースでは `何かファイルを開いて` 等を想定） |
| 既存状態 | `<base>/index.pkl` が破損または `<base>/index.json` が不正 JSON / `<base>/config.json` が壊れている等の異常状態 |
| モード | 自動（UserPromptSubmit フック） |

## トリガープロンプト

```text
何かファイルを開いて
```

（フック自動発火のため、プロンプト内容は本ケースでは重要ではない）

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `route.py` が `index.pkl` ロードを試行し失敗 |
| 2 | 例外を捕捉して `index.json` フォールバックロードを試行 |
| 3 | `index.json` も不正なら `{}` を返し、`select_candidates` で 0 件となり `route()` が None を返す |
| 4 | `additionalContext` を出力せず exit 0 |
| 5 | 重大な例外時は `<base>/error.log` に traceback を書き込み、それでも exit 0 |

## 期待出力

| ケース | 提示内容 |
|-------|---------|
| index.pkl 破損 / Python バージョン不一致 | サイレントに index.json 経由ロードへフォールバック（ユーザ視認不可） |
| index.json も不正 | `additionalContext` 出力なし、ユーザ応答は通常通り進行 |
| 致命的例外 | `<base>/error.log` に `=== <iso8601> route ===` ヘッダ + traceback、ユーザ応答は通常通り進行 |
| 副作用 | フックがブロックしない（プロンプト送信が成功する） |

## 分岐の根拠

設計書 v2 セクション 9.3「フェイルオープン原則」と D2「Bash 側 JSON パース禁止」。ルーティング処理は補助機能でありユーザの本来作業をブロックしてはならないため、すべての例外パスで exit 0 を貫く。

## 関連ケース

- `case-04_skip_negative` — 正常系のスコアリング動作
- spike `s2_hook_concat.py` — 複数フック additionalContext 競合時の挙動

## 備考

- 検証方法: `<base>/index.pkl` を意図的に空ファイルに書き換えてプロンプトを送信し、`<base>/error.log` の有無と通常応答が継続することを確認
- 検証スクリプト例: `printf '' > <base>/index.pkl` 後にプロンプト送信
- `build_index.py` 側の fail-open は `case-01_rebuild` の「失敗時」セクションに記載済み
