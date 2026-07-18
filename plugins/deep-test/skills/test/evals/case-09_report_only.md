# case-09 report-only モード（run なし・既存実績から報告書再生成）

`report-only` モードで、run を行わず既存の実績 YAML（run が 1 件以上記録済み）から報告書を再生成することを検証する。実績が 0 件の場合の生成不可案内は case-20 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「実績から報告書だけ作り直して」（または `/deep-test:test-report` / `report-only`） |
| 前提 | `{base}/{target-slug}/test-results.yaml` に run が 1 件以上記録済み |

## 分岐の根拠

SKILL.md「実行モード判定」（部分: report-only = Phase 0→7〔実績 YAML から報告書を再生成。run なし〕）、`${CLAUDE_SKILL_DIR}/references/flow.md` 1 章の状態遷移図（Phase0 --> Phase7: report-only）・6 章 Phase 7、`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 5 章（latest 採用の集計規則）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` 3.1（validate サブコマンド）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話時の報告対象 run: 最新 run・集計は latest）。

## 期待動作

- Phase 1〜6（setup・設計・レビュー・run 対象確定・実行・結果レビュー）を起動しない（run なし。report-only の定義）
- `start-run` を実行せず run_id を採番しない（新規 run を作らない）
- Phase 0（target-slug 解決 + venv 準備）の後、Phase 7 のみを実施する: `validate` で最終バリデーション → 通過時に `Skill(deep-test:test-report)` を起動する
- 集計は最新 run 結果（latest）を採用し、過去 run は推移として扱う（retest-policy.md 5 章）
- test-results.yaml を Edit / Write で直接編集しない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 報告書 1 ファイル（セッション作業領域直下） |
| 標準出力（要約） | 報告書パス + 集計を含む「引き渡し」 |
| 終了状態 | Phase 7 完了（report 生成） |

## 関連ケース

- case-20: report-only で実績 0 件の分岐（生成不可を案内し空の報告書を作らない）
- case-01: フルフロー（run + report を含む分岐と対）
- case-02: 再テスト（run を伴い末尾で report する分岐と対）
- case-08: run-only（run のみで report しない分岐と対）
