# case-02 一部テスト fail（3 点セット + stack_trace 収集）

scope の一部ケースに対応するテストが失敗するケース。fail 判定・defect 3 点セットのその場収集・`extras.stack_trace` の記録・severity 判定を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-api / run_id=R20260717-153000 / 対象ケース TC-UNIT-001（成功する）・TC-UNIT-002（アサーション不一致で失敗する）/ 対象プロジェクト情報 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由） |
| 前提 | pytest 基盤あり。TC-UNIT-002 に対応するテストがアサーション不一致で FAILED になる状態 |

## 分岐の根拠

SKILL.md「実行フロー」手順 4・「検証（チェックリスト）」、references/unit-execution.md 4 章（出力解析）・6 章（defect の組み立て）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（fail 時の必須 3 点セット）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md`（判定フロー）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 4 章（defect / extras.stack_trace）。

## 期待動作

- TC-UNIT-001 は pass、TC-UNIT-002 は fail と判定し、scope 全件（2 エントリ）を返す
- fail 判定の確定直後（返却の直前ではなくその場）に defect 3 点セットを収集する:
  - reproduction_steps: 環境情報（OS・ランタイムバージョン・ランナー名とバージョン・実行ディレクトリ）を先頭に、実行コマンド・失敗テスト識別子・発生条件（毎回再現か）を番号付きで記述
  - test_data: 失敗テストの入力値・期待値・実際値（アサーションメッセージから抽出）
  - evidence: `90_runner-log.txt` / `91_stack-trace.txt` の相対パス（実在するファイル）
- スタックトレースの主要部を `defect.extras.stack_trace` に記録し、全文を `91_stack-trace.txt` として保存する（unit-execution.md 6 章）
- `defect.severity` を severity-policy.md の判定フローで付与する（判定に迷ったら高い側に倒す）
- fail の詳細を defect に記録したうえで、actual に実際の結果（失敗内容の要約）を記載する
- SKIPPED や pass への書き換え・失敗の隠蔽を行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | evidence/R20260717-153000/{case_id}/ へ実行ログ 90_runner-log.txt を保存し、fail ケースはスタックトレース全文 91_stack-trace.txt を追加（defect 3 点セットの evidence として実在パスを記録）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 2 件。fail エントリは defect＝reproduction_steps・test_data・evidence の 3 点セット + severity + extras.stack_trace 付き）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却（TC-UNIT-001 pass / TC-UNIT-002 fail。pass への書き換え・隠蔽なし） |

## 関連ケース

- case-01: 全ケース pass（正常系）
- case-04: タイムアウト超過（blocked の分岐）
