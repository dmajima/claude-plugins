# case-20 report-only モードで実績 0 件（run なし）→ 報告書を生成せず生成不可を案内

`report-only` モードで、対象の test-results.yaml に run が 1 件も記録されていない（未実行・init 直後）場合に、憶測で空の報告書を作らず、生成不可を案内して run を含むモードでの実行を促すことを検証する。実績が 1 件以上ある正常系（報告書再生成）は case-09 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「実績から報告書だけ作り直して」（または `/deep-test:test-report` / `report-only`） |
| 前提 | `{base}/{target-slug}/test-results.yaml` が存在しない、または存在しても `runs[]` が 0 件（未実行・init 直後）。test-cases.yaml は存在してよい |

## 分岐の根拠

SKILL.md「実行モード判定」（部分: report-only = Phase 0→7〔実績 YAML から報告書を再生成。run なし〕）、`${CLAUDE_SKILL_DIR}/references/flow.md` 1 章の状態遷移図（`Phase0 --> Phase7: report-only`）・6 章 Phase 7（`validate` → `Skill: test-report`）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` 3.1（validate サブコマンド）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（報告対象 run: 最新 run。対象実績がない場合の前提不成立）。

## 期待動作

- Phase 1〜6（setup・設計・レビュー・run 対象確定・実行・結果レビュー）を起動しない（run なし。report-only の定義）
- `start-run` を実行せず run_id を採番しない
- Phase 0（target-slug 解決 + venv 準備）の後、Phase 7 で `validate` を実行し、**実績 0 件（run なし）で前提が成立しないことを検出**する
- 報告書を生成できない旨を案内する（validate または test-report が前提不成立で中断。**憶測で空の報告書・pass 0 件の報告書を作らない**）
- run を含むモード（フル / run-only / 再テスト）での実行を案内する
- test-results.yaml を Edit / Write で直接編集しない（空の run を捏造しない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実績 0 件のため報告書を生成しない。test-results.yaml へも書き込まない） |
| 標準出力（要約） | 報告書を生成できない理由（対象実績 0 件）と、run を含むモードでの実行案内 |
| 終了状態 | 前提不成立で生成せず案内に留める（空の報告書を作らない） |

## 関連ケース

- case-09: report-only の正常系（run 1 件以上から報告書を再生成する主系）。本ケースはその実績 0 件の分岐
- case-01: フルフロー（run + report を含む分岐）
- case-08: run-only（run のみで report しない分岐）
