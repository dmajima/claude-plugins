# プラグイン共通 references（人間向けインデックス）

`deep-test` プラグインの全スキル（オーケストレータ `test` / フェーズスキル 6 種 / 実行スキル 6 種）が共通参照する SSOT 規範群のディレクトリです。
本ファイルは **人間（利用者・開発者）向けのリファレンス** であり、Claude のスキル動作では参照されません。スキル動作時のナビゲーションには `references/CLAUDE.md` が使われます。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| `CLAUDE.md` | Claude エージェント向けのナビゲーション・SSOT 所有権一覧（AI が最初に読む） |
| `common-references.md` | 全 worker スキル（フェーズ 6 + 実行 6 の 12 スキル）共通の参照インデックス |
| `test-levels.md` | 8 テストレベルの定義・入口/出口基準・スキルマッピング・ケース ID プレフィクス |
| `yaml-schema.md` | 実績 YAML 共通の記述規約・操作規約（results_manager.py サブコマンド・exit code）。スキーマ定義群のハブ |
| `yaml-schema-cases.md` | test-cases.yaml の完全スキーマ（meta / cases[] / revision・承認・削除の規則） |
| `yaml-schema-results.md` | test-results.yaml の完全スキーマ（meta / runs[] / results[] / defect / latest） |
| `yaml-schema-analysis.md` | analysis.yaml の完全スキーマ（test-analyze が生成する対象理解の材料。source_availability 縮退・リスク二軸） |
| `report-format.md` | 報告書フォーマット（Excel シート構成・Markdown 章立て・スタイル・免責注記） |
| `evidence-policy.md` | NG 時提出物（再現手順・検証データ・エビデンス）の要件・二段バリデーション・機微情報マスキング |
| `severity-policy.md` | 欠陥重要度（本番影響度）の enum 値と判定基準（プラグイン内で唯一の定義場所） |
| `retest-policy.md` | 再テストモード・status×モード対象判定マトリクス・latest 採用の集計規則 |
| `data-locations.md` | 実績・エビデンス・報告書の配置パス・target-slug 解決・エビデンス移送・保持方針 |
| `playwright-mcp.md` | Playwright MCP の登録・既存登録検出・起動オプション・正本ツールリスト（各スキル frontmatter の同期元） |
| `playwright-test.md` | Playwright Test（`.spec.ts` + フィクスチャ）実行規約・`fixtures.yaml`（test-fixture 生成・Phase 1.6）スキーマ・認証(storageState)/モック/シード/base のパターン規範 |
| `agents.md` | レビューエージェントの選定表・起動方式・プロンプト組み立て・並列起動の原則 |
| `execution-policy.md` | 実行共通規範（ゲート 4 種・条件付き動的検証・SKIPPED 記録・タイムアウト・非対話既定値表） |
| `scripts/setup/` | venv 構築・削除スクリプト（`setup_venv.sh` / `teardown_venv.sh`）と全スキル共通の `requirements.txt` |
| `scripts/run/` | タイムアウト付き Python 実行ラッパー（`run_via_job.sh`。任意利用）とエビデンスアーカイブ（`archive_evidence.sh`。外部共有・クリーンアップ用） |

## 設計方針（人間向けの要点）

- ここに置く規範は **複数スキルから参照される横断的関心事** に限り、各規範の唯一の定義場所（SSOT）を `CLAUDE.md` の所有権一覧で管理します
- 欠陥重要度（severity）の enum 値・判定基準は `severity-policy.md` にのみ定義し、他ファイルへは複製しません
- `test-results.yaml` は LLM が直接編集せず、オーケストレータ `test` の専用スクリプト（results_manager.py）経由に一元化します

## 編集時の注意

- ファイルを追加・改名した場合は、本ファイルと `CLAUDE.md` のナビゲーション表・SSOT 所有権一覧を更新してください
- 共通 references から個別スキル固有のロジックへ依存を持ち込まないでください（適用先スキルを示すポインタ記載は可）
