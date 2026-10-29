# case-07 design-only モード（設計レビューゲートまでで完了・run へ進まない）

`design-only` モードで、設計フェーズと設計レビューゲートまでを実施し、run（Phase 4 以降）へ進まずに完了扱いとすることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「テストケースを設計するところまでやって」（または `/deep-test:test design-only`） |
| 前提 | 対象 target-slug は未作成。要件・対象説明はユーザー提供。run は行わない指示 |

## 分岐の根拠

SKILL.md「実行モード判定」（部分: design-only = Phase 0→2→3〔設計レビューゲートまで。run へ進まない〕）、`${CLAUDE_SKILL_DIR}/references/flow.md` 1 章の状態遷移図（Phase3 --> Phase4: PASS〔design-only はここで完了〕）・2 章（Phase 2〜3 の入出力）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1.1（設計レビューゲート）。

## 期待動作

- Phase 0: target-slug を解決し（未作成のため新規作成を確認）、venv 準備後に `results_manager.py init` を実行する
- Phase 2: `Skill(deep-test:test-design)` を起動し、test-plan.md と test-cases.yaml（全ケース draft）を生成させる
- Phase 3: `Skill(deep-test:test-review, context=design)` を起動する。PASS なら test-review が approved 化まで実施した結果を受領し、**設計レビューゲート到達で完了扱いとする**
- NEEDS REVISION の場合は test-design へ差し戻す修正ループ（上限 3 回。execution-policy.md 1.1）を回す
- **Phase 4 以降（select・ゲート判定・start-run・run 実行・結果レビュー・報告）へ進まない**（run へ進まないのが design-only の定義）
- `start-run` を実行せず run_id を採番しない（run レコードを残さない）
- 引き渡しに、生成した test-plan.md / test-cases.yaml のパスと「実行は未実施。run するには run-only またはフルフローで継続」の案内を含める

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/test-plan.md` と `test-cases.yaml`（設計レビューゲート通過後は該当ケースが approved）。test-results.yaml は run を含まないため runs / results を追記しない |
| 標準出力（要約） | 設計成果物のパスと設計レビュー結果（PASS）・実行未実施の案内。SKILL.md「引き渡し」に準拠 |
| 終了状態 | Phase 3（設計レビューゲート）到達で完了。run（Phase 4 以降）未着手・run_id 未採番 |

## 関連ケース

- case-01: フルフロー（design-only の後続 Phase 4〜7 を含む分岐と対）
- case-08: run-only（設計を省略し run から実施する分岐と対）
- case-04: 設計レビュー NEEDS REVISION の遡行ループ（design-only でも同じ上限 3 回が適用される）
