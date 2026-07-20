# case-01 pytest 検出 → 実行 → 全ケース pass

オーケストレータから委譲され、pytest 基盤が揃った Python プロジェクトで scope 全ケースが pass するケース。ランナー検出・プロジェクト環境の尊重・ケースマッピング・エビデンス保存・中間結果 JSON 返却を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-api / run_id=R20260717-150000 / 対象ケース TC-UNIT-001〜003（各ケースの data に test_pattern 記載あり）/ 対象プロジェクト情報（Python・プロジェクトルート） |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由） |
| 前提 | `pyproject.toml`（pytest 設定）と `tests/` 配下のテストコードが存在し、プロジェクト直下に `.venv/` 構築済み。全テストが成功する状態 |

## 分岐の根拠

SKILL.md「実行フロー」手順 2〜3・手順 6、references/unit-execution.md 1.2（検出表）・1.3（プロジェクト環境の尊重）・2.2（対応付け手順）・5 章（エビデンス保存）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章（中間結果返却フォーマット）・7 章（ユニットのエビデンス自動収集）。

## 期待動作

- `pyproject.toml` 等から pytest を検出し、プロジェクトの `.venv/` の python 実体で `-m pytest` を実行する（unit-execution.md 1.2 / 1.3。システム環境へのインストールを行わない）
- ケースの data の test_pattern と実行結果の nodeid を突合し、TC-UNIT-001〜003 をすべて pass と判定する（unit-execution.md 2.2）
- 各ケースの実行ログ（当該ケース関連の抜粋 + サマリ行）を `evidence/R20260717-150000/{case_id}/90_runner-log.txt` に保存し、{target-slug}/ 直下基準の相対パスで evidence に記録する
- priority: high の pass ケースにもエビデンスを付与する（SKILL.md「検証（チェックリスト）」）
- 中間結果 JSON（skill: "test-run-unit" / 受領した run_id / results 3 エントリ / executed_by: "test-framework" / case_revision 付き）を 1 つのコードブロックで返却する（execution-policy.md 4 章）
- test-results.yaml への書き込み（Edit / Write）を行わない（SKILL.md「重要な制約」）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | ランナー実行ログを evidence/R20260717-150000/{case_id}/90_runner-log.txt へ保存（priority: high の pass にもエビデンスを付与）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 3 件・executed_by: test-framework・case_revision 付き）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 3 件（TC-UNIT-001〜003）を 1 エントリずつ pass で返却 |

## 関連ケース

- case-02: 一部テスト fail（defect 収集の分岐）
- case-03: ランナー不在（skipped の分岐）
