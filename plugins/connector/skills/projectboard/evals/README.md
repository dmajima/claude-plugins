# projectboard スキル evals

projectboard スキルの動作期待値ケース集。各ケースは外部 API（HUE ProjectBoard）と認証情報に
依存するため自動実行（runnable）対象外であり、Claude Code セッションでの目視確認用の仕様書として機能する。

## ケース一覧

| ケース | シナリオ | 主な分岐 |
|-------|---------|---------|
| [case-01_task_read.md](case-01_task_read.md) | URL からタスク一覧を CSV 化（読み取り） | 読み取り経路（承認ゲートなし） |
| [case-02_sheet_structure.md](case-02_sheet_structure.md) | シート全体の構造解析・クリティカルパス（読み取り） | 解析経路（analyze_schedule.py） |
| [case-03_task_add.md](case-03_task_add.md) | タスク追加（書き込み） | 承認ゲート + addNode + 反映検証 |
| [case-04_task_update.md](case-04_task_update.md) | ステータス更新（書き込み） | ID 解決 + 承認ゲート + updateNodeContent |
| [case-05_credentials_missing.md](case-05_credentials_missing.md) | 認証情報なし | API を呼ばず対話取得フォールバック（中止時のみ終了） |
| [case-06_session_expired.md](case-06_session_expired.md) | セッション切れ（401） | 自動再ログイン + リトライ |
| [case-07_write_cancel.md](case-07_write_cancel.md) | 書き込み承認で中止 | POST 未発行・正常中止 |
| [case-08_subagent_credentials_missing.md](case-08_subagent_credentials_missing.md) | サブエージェント呼び出しで認証情報なし | 質問せず `credentials_missing` マニフェスト返却（呼び出し元が対話復帰） |
| [case-09_relogin_bad_credentials.md](case-09_relogin_bad_credentials.md) | 自動再ログインで badCredentials（セッション例外の境界） | 同一値で再送せず対話取得フォールバックへ（サブエージェント時は `auth_failed` 返却） |

## 構造検証

外部 API を呼ばない読み取り専用の構造検証は `demo.sh` で実行できる:

```bash
bash demo.sh             # 計画のみ表示（副作用ゼロ）
bash demo.sh --no-whatif # 検証を実行（読み取り専用チェックのみ）
```

### demo.sh で検証できる範囲 / できない範囲

| 検証できる（demo.sh） | 検証できない（目視確認が必要） |
|---|---|
| SKILL.md / references / scripts / evals の存在 | 実ログイン（フォーム認証・SSO 検知） |
| 全 .sh の bash 構文 | 実 API の取得・SPA フォールバック検知 |
| urlkey.py の round-trip（正常 + 不正入力の拒否） | 書き込み（addNode / updateNodeContent）の実発行と反映 |
| frontmatter の name 整合 | AskUserQuestion 承認 UI・中止フロー |

実 API を伴う動作（ログイン・取得・書き込み・承認 UI）は検証用シートを用意のうえ、
各ケースの起動フレーズを Claude Code セッションに入力して目視確認する。
特に書き込み API はボディの一部が推定仕様のため、初回は検証用シートでの実機確認を必須とする
（[../references/api-write.md](../references/api-write.md) セクション 7-8）。
