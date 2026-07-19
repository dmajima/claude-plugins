<!-- TEST-RUN-PERF-EVAL-ENDPOINTS-SENTINEL-v1 -->
# case-10 environment.yaml の endpoints[] 由来 base URL で計測（コンテナ派生環境の免責注記材料つき）

オーケストレータが test-environment（Phase 1.7）の environment.yaml `endpoints[]` から得た base URL（テスト用派生環境・127.0.0.1 バインド）を対象として応答時間を計測することを検証する。受領形・計測手順は既存のままである一方、performance 固有の追加規範として「コンテナ派生環境での計測であり、本番構成の性能を代表しない」旨の免責注記材料を特記事項として返すことを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260719-153000 / 対象ケース TC-PERF-001（automation: playwright・応答時間・閾値あり）/ 対象 URL `http://127.0.0.1:18080`（environment.yaml の `endpoints[]` 由来・`purpose: browser`・`health: healthy`） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | test-environment の action=up が完了済みで `endpoints[]` が確定している（up・health 確認は test-environment / オーケストレータの責務。本スキルは base URL の受領のみ）。Playwright MCP はロード済み |

## 分岐の根拠

SKILL.md「前提」（対象アプリ情報〔URL 等〕は environment.yaml の `endpoints[]` 由来の base URL として受領する場合がある。受領形・実行手順は不変・出所の注記のみ）・「引き渡し」（コンテナ派生環境〔endpoints[] 由来 base URL・`{slug}-test`〕で計測した場合は「本番構成の性能を代表しない」旨の免責注記材料を特記事項として明記して返す。オーケストレータが results_manager.py の annotate で登録・報告書の「所見・注記」へ機械出力。本スキルは材料の提供まで・手動転記しない）、`${CLAUDE_SKILL_DIR}/references/performance-execution.md` 1 章（単一セッション応答時間）・2 章（複数回計測と中央値採用）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 8 章（endpoints[]）。

## 期待動作

- 受領した base URL（`http://127.0.0.1:18080`）を通常の対象と同一の受領形として扱い、複数回計測・中央値採用・閾値判定（performance-execution.md 1〜3 章）を既存手順どおり実施する（出所による計測手順の変更をしない）
- **コンテナ派生環境での計測であることの免責注記材料**（「コンテナ派生環境での計測であり、本番構成の性能を代表しない」旨）を中間結果 JSON とあわせて特記事項として明記して返す（SKILL.md「引き渡し」。annotate 登録はオーケストレータの責務・本スキルは材料の提供まで・報告書へ手動転記しない）
- environment.yaml を書き換えない（`endpoints[]` は受領材料。生成・更新は test-environment の専有）
- 環境の up / down・health 判定を本スキルで行わない（稼働状態の管理は test-environment / オーケストレータの責務）
- 実測値の記録（actual に中央値・計測回数・閾値・判定）・`executed_by: playwright-mcp` は既存規範のまま
- 中間結果 JSON を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-153000/TC-PERF-001/` 配下に計測記録（既存命名）。environment.yaml / test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / results 1 件・executed_by: playwright-mcp）+ コンテナ派生環境計測の免責注記材料（特記事項）を 1 応答で返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-PERF-001）を 1 エントリで返却 + 免責注記材料の明記（annotate 登録はオーケストレータが実施） |

## 関連ケース

- case-01: ユーザー起動 URL での応答時間 pass（計測手順〔3 回計測中央値〕が同一であることの対比）
- case-05: Playwright MCP 未ロードによる skipped（endpoints[] 由来 URL でも実行手段の判定は既存のまま）
