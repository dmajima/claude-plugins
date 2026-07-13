# Case 04: 認証失敗（gh auth status 失敗 — API を呼ばず認証確立を確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://github.com/contoso/webapp/pull/42 のレビュースレッド一覧を取得して" |
| 既存状態 | `gh auth status` が終了コード != 0（未認証） |

## 期待動作

1. `gh auth status` の終了コード確認 → 認証失敗を検出
2. **API を呼ばない**（未認証のまま GitHub API を叩かない）
3. ユーザーに `gh auth login` の実行（または `GH_TOKEN` / `GITHUB_TOKEN` 環境変数の設定）を案内する。`gh auth login` は対話ログインのためトークン値の代理受領はしない
4. ユーザーの実行完了後に `gh auth status` を再確認し、認証済みになれば元の操作（スレッド一覧取得）を続行する
5. ユーザーが中止を指示した場合のみ終了する
6. サブエージェント実行時（`AskUserQuestion` 利用不可）は案内せず `{"status":"error","error":"credentials_missing","service":"github","detail":"gh CLI 未認証"}` マニフェストを返す（subagent-protocol.md セクション 3.5 で呼び出し元が復帰）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | 「gh CLI が未認証」の報告 + `gh auth login` / 環境変数設定の案内 →（認証確立後）元の操作の実行結果 |
| 終了状態 | 認証確立後: 元の操作（スレッド一覧取得）を完遂 / 中止指示時: API 未呼び出しで終了 |

## 分岐の根拠

認証失敗時のフォールバックフロー。API を呼ばないこと（認証情報の不正送信防止）と、認証確立の案内 → 再確認 → 続行によりユーザーが操作を完遂できることの両方を確認する。credentials-manager プラグイン / credentials.json には依存しない（GitHub 認証は `gh` CLI が管理する）。

## 関連ケース

- `case-08_subagent_read_pr.md`（サブエージェント呼び出しの正常系）
