# case-07 外部 fetch 失敗（401/403/404/timeout）の fetch_status: failure 記録

ホワイトリスト適合 URL への fetch が HTTP エラー（401/404 等）またはタイムアウトで失敗するケース。fetch_status の 3 値のうち `failure` の記録を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `spec` なし / `fetch-external=auto` / description に credentials.json 登録済みドメインの外部リンク 1 件（ただし取得時に 404 または 401 を返す） |
| モード | 委譲呼び出し（auto 明示・非対話） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/expected-behavior.md` セクション 3.4（fetch_status に success / failure / skipped の 3 値を要求）、references/checklist.md セクション C の C-Auto-4（external-link の fetch_status に success/failure/skipped を明示）、`${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md`（HTTP エラー分岐）、`${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md`（fetch 安全方針）。

## 期待動作

- ホワイトリスト照合を通過し fetch を試行する（safe-external-fetch.md セクション 1.2）
- fetch が HTTP 401/403（認証失敗）を返した場合: 即座に fetch を中止し、sources_used に `fetch_status: failure`（理由: HTTP 401/403）として記録する。認証情報の値は出力しない（U12）
- fetch が HTTP 404（リソース不在）を返した場合: sources_used に `fetch_status: failure`（理由: HTTP 404）として記録する
- fetch がタイムアウト（safe-external-fetch.md の時間上限超過）した場合: `fetch_status: failure`（理由: timeout）として記録する
- fetch 失敗により当該情報源が欠落することを conflicts / 制約事項に明記し、他の情報源（description 本文・リポジトリ内資料）で推論を継続する
- fetch 失敗を「問題なし」や「情報なし」と混同せず、明示的に failure として区別する（U13 の精神に整合）
- 出力 JSON の sources_used に fetch_status: failure が含まれる（C-Auto-4）

## 関連ケース

- case-06: fetch-external=ask 既定 + 承認（fetch 成功系）
- case-02: fetch-external=auto ホワイトリスト不一致（skipped 系）
