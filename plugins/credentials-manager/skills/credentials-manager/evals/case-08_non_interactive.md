# Case 08: 非対話モードでの保存

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "認証情報を保存。name=anthropic-api-key, type=api_key, value=sk-ant-abcdefghij1234567890, domain=api.anthropic.com, --non-interactive" |
| 引数 | name / type / value / domain を全指定 |
| フラグ | `--non-interactive` |
| 既存状態 | `credentials.json` 不在 |

## 期待動作

### Phase 1: 実行モード判定

- `--non-interactive` フラグ + 全パラメータ指定により非対話モード確定
- `AskUserQuestion` を呼ばない

### Phase 2: パス解決と書き込み

- 解決パスを確定（リポジトリ内なら project-scoped、外ならuser-scoped）
- `.claude/.local/` の `.gitignore` 未登録時は警告のみ表示し、ユーザ確認なしで続行（非対話モード）
- エントリを書き込み

### Phase 3: 確認

- マスク済み値と保存パスを表示
- ユーザ操作待ちなしで終了

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `credentials.json` |
| 標準出力（要約） | "Saved credential 'anthropic-api-key' (api_key): sk-a****7890 — domains: api.anthropic.com" |
| 終了状態 | 成功 |

## 分岐の根拠

このケースは「実行モード判定 = 非対話」分岐に該当する。引数で全パラメータが揃うため `AskUserQuestion` を発火しない。参照系（複数件マッチ時の選択等）の非対話動作は `credentials-reader` 側 `references/auto-match.md` を参照。

## 関連ケース

- `case-01_save_with_url.md`（対話モードでの保存差分）
- `case-07_delete_with_confirm.md`（対話モードでの削除確認との差分）
