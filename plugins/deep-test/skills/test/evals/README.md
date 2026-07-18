# test（オーケストレータ）evals

本ディレクトリは `test` オーケストレータスキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | モード |
|------|-----------|------------|-------|
| 01 | case-01_full_flow.md | フルフロー正常系（全フェーズ委譲・全ゲート通過・実績記録・報告） | フル・対話 |
| 02 | case-02_retest_ng_only.md | 再テスト ng-only（select 抽出・対象判定マトリクス・回帰非代替注記・実績マージ） | 再テスト・対話 |
| 03 | case-03_mcp_gate_handoff_resume.md | MCP 未ロード → 再起動ハンドオフ停止 → 再起動後 resume で途中復帰 | フル → resume |
| 04 | case-04_design_review_revision_loop.md | 設計レビュー NEEDS REVISION → design 修正ループ（2 回目 PASS で収束する主系） | フル・対話 |
| 05 | case-05_non_interactive_defaults.md | 非対話モードの既定値動作（承認スキップ・Markdown・manual-assist skipped・slug 1 件自動採用） | フル・非対話 |
| 06 | case-06_record_validation_missing_defect.md | fail 記録の一次バリデーション欠落（exit 2）→ 追加取得指示 → 再 record（exit 3 / 64 との区別を含む） | フル（Phase 5） |
| 07 | case-07_design_only.md | design-only モード（Phase 0→2→3・設計レビューゲートまで・run へ進まない） | 部分・対話 |
| 08 | case-08_run_only.md | run-only モード（levels 指定あり・select full を指定レベルで絞り込み・Phase 5 で完了） | 部分 |
| 09 | case-09_report_only.md | report-only モード（Phase 0→7・run なし・既存実績から報告書再生成） | 部分 |
| 10 | case-10_retest_full.md | 再テスト full（対象判定マトリクス・na / deprecated 除外） | 再テスト |
| 11 | case-11_human_approval_declined.md | 人間承認ゲートで「中断する」選択 → scope・実績未変更で中断（start-run 未実行・再開手段案内） | フル・対話 |
| 12 | case-12_production_destructive_excluded.md | 環境安全（本番相当 URL は既定禁止・破壊的操作ケースの承認ゲート提示 / 例外時 scope 除外） | フル・対話 |
| 13 | case-13_results_review_needs_revision.md | 結果レビュー NEEDS REVISION → ids 再実行による遡行（append-only・上限 3 回） | フル（Phase 6） |
| 14 | case-14_resume_no_interrupted_run.md | resume 起動で中断 run なし → approved ケースあり時は run-only 相当を提案（cases 不在はフル案内） | resume・対話 |
| 15 | case-15_interactive_multiple_slug_selection.md | 対話で既存 target-slug 複数 → AskUserQuestion で一覧 +「新規作成」を提示 | フル・対話 |
| 16 | case-16_design_review_loop_exceeded.md | 設計レビュー修正ループの上限 3 回超過 → 対話 3 択（続行 / 中断 / 指摘許容）と選択別の帰結 | フル・対話 |
| 17 | case-17_non_interactive_multiple_slug_error.md | 非対話で既存 target-slug 複数 → 自動選択せずエラー中断（明示指定を案内） | フル・非対話 |
| 18 | case-18_approved_case_gate_draft_mixed.md | 承認済みケースゲート（select 結果に draft 混入 → test-review 設計文脈を先行 → approved 後に Phase 4 復帰） | 再テスト / run-only |
| 19 | case-19_run_only_levels_unspecified.md | run-only で levels= 未指定（対象レベルを憶測補完せず確認 / 非対話はエラー中断。case-08 の対） | 部分 |
| 20 | case-20_report_only_no_results.md | report-only で実績 0 件 → 報告書を生成せず生成不可案内（case-09 の対） | 部分 |
| 21 | case-21_retest_ids.md | 再テスト ids（指定 ID のみ・na 警告・deprecated 除外。case-10 の対） | 再テスト |
| 22 | case-22_setup_partial_received.md | Phase 1 で test-setup が PARTIAL を返す（対話）→ 停止せず続行しユーザーへ提示・利用不可項目の影響を実行フェーズへ引き継ぐ | フル・対話 |
| 23 | case-23_phase7_validate_violation_supplement_rerun.md | Phase 7 最終 validate の scope 突合違反（記録欠落）→ 報告書生成せず Phase 5 復帰・同一 run_id で欠落補完 → finish-run 再確定 → validate 再通過 | フル（Phase 7） |
| 24 | case-24_setup_partial_received_non_interactive.md | Phase 1 で test-setup が PARTIAL を返す（非対話）→ 提示せず自動続行・skipped 見込みを記録（case-22 の対） | フル・非対話 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | ユーザー発話（またはコマンド）・前提状態（環境・既存データ） |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き（呼ばれるスキル・スクリプト・ゲート判定・出力） |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（SKILL.md「引き渡し」フォーマットへの参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 分岐網羅の考え方

本スキルは制御専任のため、evals の軸は「モード判定 × ゲート判定 × スクリプト連携 × 安全系」で構成する。

- モード軸: フル（case-01）/ 再テスト ng-only（case-02）/ resume（case-03・14）/ 非対話（case-05・17）/ design-only（case-07）/ run-only（case-08、levels 未指定は case-19）/ report-only（case-09、実績 0 件は case-20）/ 再テスト full（case-10）/ 再テスト ids（case-21）
- ゲート軸: 4 ゲート通過（case-01）/ 承認済みケースゲート draft 混入（case-18）/ MCP ゲート停止（case-03）/ 設計レビューゲート遡行（case-04・16）/ 人間承認スキップ（case-05）/ 人間承認否認（case-11）/ 結果レビュー遡行（case-13）
- スクリプト軸: init〜summary の正常系（case-01・02）/ record exit 2 の一次バリデーションと exit 3 / 64 の区別（case-06）/ validate の最終バリデーション違反（scope 突合の記録欠落）による Phase 5 復帰・欠落補完（case-23）/ select の対象判定マトリクス（case-02・10・21・13）
- 安全系・解決系の軸: 環境安全（本番既定禁止・破壊的操作。case-12）/ target-slug 解決の対話・非対話対（case-15・17）
- setup 受領軸: Phase 1 の setup 検出結果の受領（新規 MCP 登録・未ロードは再起動ハンドオフ停止＝case-03 / PARTIAL は停止せず続行〔対話＝case-22 / 非対話＝case-24〕）

各分岐は「主分岐 1 ケース 1 ファイル」を原則とし、対の分岐（run-only の levels 未指定＝case-19、report-only の実績 0 件＝case-20、再テスト full と ids＝case-10 / 21、setup PARTIAL 受領の対話 / 非対話＝case-22 / 24）は独立ファイルに分割して相互に「関連ケース」でリンクする。

テストの実務的な挙動（Playwright 操作・レビュー観点・報告書体裁）は各 worker スキルの evals が担い、本 evals では扱わない。
