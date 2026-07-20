# test-run-unit evals

本ディレクトリは `test-run-unit` 実行スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_pytest_all_pass.md | pytest 検出 → 実行 → 全ケース pass（マッピング・ログエビデンス保存） | 委譲 |
| 02 | case-02_partial_fail_stack_trace.md | 一部テスト fail（defect 3 点セット + extras.stack_trace 収集） | 委譲 |
| 03 | case-03_runner_absent_skipped.md | ランナー不在・テストコード不在 → scope 全ケース skipped + reason | 委譲 |
| 04 | case-04_timeout_blocked.md | ケースタイムアウト超過 → blocked + reason（次ケースへ継続） | 委譲 |
| 05 | case-05_mapping_unresolved.md | ケースとテストの対応付け不能（パターン未記載 → blocked / 合致 0 件 → skipped の使い分け） | 委譲 |
| 06 | case-06_standalone_missing_inputs.md | 単独起動で必須入力欠落 → 実行せずオーケストレータ経由を案内 | 単独 |
| 07 | case-07_manual_assist.md | automation: manual-assist × 対話（人手確認・executed_by: human-assisted で記録） | 委譲 |
| 08 | case-08_manual_assist_non_interactive.md | automation: manual-assist × 非対話（skipped + reason で返却。case-07 の対） | 委譲 |
| 09 | case-09_container_exec_run.md | ホストにランナー不在 + environment.yaml の exec_forms[] あり + 環境 up → コンテナ内 exec で実行（代替経路・executed_by: test-framework 不変。case-03 の対） | 委譲 |
| 10 | case-10_env_down_skipped.md | ホストにランナー不在 + exec_forms[] あり + 環境 down → 代替経路を選択せず skipped（環境を起動しない。case-09 の対） | 委譲 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（スキルの「引き渡し」フォーマットへの参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 分岐の軸について

実行スキルはオーケストレータ `test` からの委譲起動が標準のため、本 evals の主軸は **実行手段の可否と結果 status の分岐**（pass / fail / blocked / skipped）である。
起動形態の軸（委譲 / 単独）は case-06 のみで扱う: 単独起動時は run_id 採番・実績記録がオーケストレータの責務であるため、必須入力が欠落した状態では実行せず案内に留まることを検証する。
