# case-06 単独起動・必須入力欠落 → 実行せず案内

ユーザーがオーケストレータを経由せず直接起動し、必須入力（target-slug / run_id / 対象ケース / 対象アプリ情報）が欠落しているケース。実行せずオーケストレータ経由の起動を案内することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「システムテストを実行して」「業務シナリオを通しで検証して」（run_id・target-slug・対象ケースの指定なし） |
| 起動形態 | 単独（ユーザー直接起動） |
| 前提 | オーケストレータの start-run が実行されておらず run_id が存在しない |

## 分岐の根拠

SKILL.md「実行モード判定」（ユーザーが直接起動〔引数不足〕→ 単独: オーケストレータ `test` 経由〔`/deep-test:test`〕での実行を案内する。実績記録・ゲート判定を伴うため単独完結はしない）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` 2.2（run_id は results_manager.py start-run が採番）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 3 章（実績 YAML 書き込みはオーケストレータの責務）。

## 期待動作

- 業務シナリオの実行を開始しない（Playwright 操作・エビデンス生成を行わない）
- run_id を自前で採番しない（採番は start-run の責務。yaml-schema.md 2.2）
- `/deep-test:test`（必要に応じて run-only モード等）経由での起動を案内する
- 単独実行では実績（test-results.yaml）が記録されない旨・ゲート判定を伴うため単独完結しない旨を説明する
- 憶測で target-slug を新規作成したり、test-results.yaml を直接操作したりしない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実行しないためエビデンス生成なし。test-results.yaml も操作しない） |
| 標準出力（要約） | オーケストレータ `test` 経由での起動案内・単独では実績が記録されない旨 |
| 終了状態 | 実行せず案内に留める（run_id 未採番） |

## 関連ケース

- case-01: 委譲起動（必須入力が揃った標準経路・system シナリオ pass）
- case-05: MCP 未ロードによる skipped（委譲時の実行手段不在との対比）
