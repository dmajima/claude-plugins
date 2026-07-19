<!-- TEST-ORCH-EVAL-R2-25-SENTINEL-v1 -->
# case-25 環境統合フルフロー（Phase 1.7 provision → design 移行・全ゲート通過後 up → start-run・Phase 6 PASS 後 down）

docker 資産のある対象のフルフローで、Phase 1.7 の provision 委譲 → Phase 2（design）移行、全ゲート通過後の environment up（Phase 5 手順 0）→ `start-run`、Phase 6 PASS 後の down までの環境ライフサイクル統合が規範どおりに行われることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「このアプリをテストして」（または `/deep-test:test`） |
| 前提 | SUT に `docker-compose.yml` 等の docker 資産あり・見込みレベルに functional / integration を含む（unit のみではない）。Playwright MCP ロード済み。provision / up は成功（applicability: applicable・healthy 到達）。設計レビュー 1 回 PASS・実行結果すべて pass・結果レビュー PASS |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/flow.md` 2.1 章「Phase 別の要点」1.7（フルフローで docker 資産が見込まれる場合のみ委譲・縮退はフローを止めない）・5（手順 0: environment up・down は Phase 6 判定後）・SKILL.md「検証」（`{slug}-test` の残存コンテナがない）、references/flow.md 1 章（Phase1_6 / 1_5 → Phase1_7 → Phase2 の遷移）・2 章（Phase 1.7 の入出力・up は Phase 5 手順 0・down は Phase 6 判定後）・3 章（ゲート順序: select → 承認済みケース → 人間承認 → MCP → environment up〔ゲートではない〕→ start-run）・6 章（Phase 1.7 / Phase 5 手順 0 / Phase 6 down の Skill 呼出形）。

## 期待動作

- Phase 1.5（test-analyze）の後（fixture 有効時は Phase 1.6 の後）、docker 資産が見込まれるため `Skill(deep-test:test-environment)` に `action=provision levels={見込みレベルCSV}` で委譲する
- provision 返却後、environment.yaml のパス存在を確認して Phase 2（test-design）へ移行する（test-design が environment.yaml を preconditions / 環境前提の材料に消費する。縮退時もフローを止めない）
- Phase 4 の全ゲート通過後・`start-run` **直前**に手順 0 として `action=up` を委譲する（`environment.yaml` が `applicability: applicable` のときのみ。ゲートではなく、失敗は縮退でフローを止めない）
- up 完了後、environment.yaml から project 名（`{slug}-test`）・endpoints の base URL・イメージ情報を読み、`start-run --environment` の環境文字列と実行スキルへ渡す対象アプリ情報に用いる
- Phase 6 の結果レビュー PASS 後（environment が `status.state: up` の場合のみ）、`action=down run-id={run_id}` を委譲してから Phase 7 へ進む（up したまま報告へ進まない）
- test-results.yaml はすべて results_manager.py 経由で更新する（environment.yaml は test-environment の専有で、オーケストレータは読み取りのみ）
- 完了報告前の検証で `{slug}-test` プロジェクトの残存コンテナがない（down 済み）ことを確認する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | environment.yaml + `environment/` 配下の派生成果物（test-environment 生成）・test-plan.md / test-cases.yaml・test-results.yaml（`--environment` に compose project 由来の環境文字列）・報告書 |
| 標準出力（要約） | SKILL.md「引き渡し」の正常完了フォーマット（run_id・レベル別集計・報告書パス・未確認事項） |
| 終了状態 | Phase 0〜7 完了・run status=completed・環境は down 済み（up → down のワンサイクル完結） |

## 関連ケース

- case-01: 環境統合なし（docker 資産なし・従来前提）のフルフロー正常系
- case-26: Phase 6 NEEDS REVISION 時に down せず環境を維持する対
- case-27: 中断後の resume で環境を再確認・再利用する分岐
