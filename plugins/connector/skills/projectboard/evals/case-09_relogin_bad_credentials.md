# Case 09: 自動再ログインで badCredentials（セッション例外の境界 — 同一値で再送せず対話取得へ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "ProjectBoard のタスクを取得して https://example-tenant.pm.apps.worksap.com/wbs/project/abc123XYZ/issue/qQq" |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json の `hue-projectboard` エントリは `domains` 合致・username/value 非空だが、パスワードが ProjectBoard 側で変更済み（保存値は失効）。取得途中にセッションが 401 になる |

## 期待動作

### Phase 1: セッション切れの検出と自動再ログイン試行

- fetch スクリプトが 401 を受領し、`with_session.sh` が Cookie セッション例外（safe-api-access.md セクション 5）に基づき `login.sh` で再ログインを試行する（ここまでは case-06 と同一）

### Phase 2: badCredentials の検出（例外の境界）

- `login.sh` の redirect 判定が `error=badCredentials` を検知し、exit 1 で明示エラーになる
- **badCredentials は資格情報自体の失敗であり、Cookie セッション例外の適用対象外**。同一パスワードでの再ログイン・API 再送を一切行わない（無限ループ・アカウントロック誘発の防止）

### Phase 3: 対話取得フォールバックでの再取得

- credentials-precheck.md セクション 4 の対話取得フォールバックで認証情報の再確認・再取得を提示する
  - **新しい値（前回送信値と異なることを確認した値）** を受領した場合のみ再ログインを 1 回だけ再実行する（保存選択時はエントリ更新）
  - 中止選択時は API を追加発行せず終了する
- サブエージェント実行時（`AskUserQuestion` 利用不可）は質問せず `auth_failed` マニフェスト（`service: "projectboard"`）を返す（subagent-protocol.md セクション 3.3 / 3.5）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 「保存する」選択時のみ credentials.json のエントリ更新 |
| 標準出力（要約） | 「login: FAILED (bad credentials)」の報告 + 再取得の選択肢提示 →（新値受領時）再ログイン・取得結果 |
| 終了状態 | 新値受領時: 再ログイン 1 回で続行 / 中止時: badCredentials 受領後の追加リクエスト 0 で終了 |

## 分岐の根拠

Cookie セッション例外（同一資格情報でのセッション再確立を各 1 回許容）の **境界失敗** ケース。例外が適用されるのはセッション期限切れ（資格情報は有効）の場合のみで、`badCredentials` を受領した時点で safe-api-access.md セクション 5 の一般則（同一認証情報でのリトライ厳禁）に戻る。この境界により例外規定がロック誘発・総当たりの抜け穴にならないことを確認する。

## 関連ケース

- `case-06_session_expired.md`（資格情報が有効でセッションのみ切れた場合 — 例外が適用され自動再ログインで続行する対比）
- `case-05_credentials_missing.md`（そもそも認証情報が未登録の場合）
