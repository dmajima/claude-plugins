# references/ 読み込みガイド（プラグイン共通）

## 目的と範囲

`deep-test` プラグインの全スキル（オーケストレータ `test` / フェーズスキル 7 種 / 実行スキル 6 種）が共通参照する **SSOT 規範群** のナビゲーション。
テストレベル定義・YAML スキーマ・severity 基準・エビデンス要件・再テスト判定・データ配置・Playwright MCP 規約・エージェント運用・実行共通規範を集約する。

## 原則

- **依存方向は個別スキル → 共通 references の一方向**。共通 references は個別スキルのロジック・手順本体に依存しない（適用先スキルを示すポインタ・適用一覧の記載は許容）
- 欠陥重要度（severity）の enum 値・判定基準は **`severity-policy.md` が唯一の定義場所**。`yaml-schema-results.md` / `evidence-policy.md` / `report-format.md` は severity-policy.md への片方向参照のみ行い、基準を複製しない
- 各 worker スキル（13 スキル）の SKILL.md からの共通参照は `common-references.md` への 1 行参照に集約する
- `test-results.yaml` は LLM が Edit/Write で直接編集しない（オーケストレータ `test` の専用スクリプト経由に一元化）。共通規約・操作規約は `yaml-schema.md`、スキーマ本体は `yaml-schema-results.md`、配置は `data-locations.md` を参照
- 実行手段（Playwright MCP・テストランナー・外部ツール）が利用不可の場合は実行を偽装せず `skipped` + reason で記録する（`execution-policy.md`）
- 各スキル frontmatter の Playwright MCP ツール列挙は `playwright-mcp.md` の正本ツールリストから同期する（同期義務）
- 本ディレクトリへのファイル追加・改名時は本ファイルのナビゲーション表と SSOT 所有権一覧を同期する

## ナビゲーション（どの場面でどれを読むか）

| 場面 / タスク | 参照先 |
|-------------|-------|
| references 全体の構成・SSOT 所有権を確認する | 本ファイル（`CLAUDE.md`） |
| worker スキルとして共通参照先を一括確認する | `common-references.md` |
| テストレベルの定義・入口/出口基準・担当スキル・ケース ID プレフィクスを確認する | `test-levels.md` |
| 実績 YAML 共通の記述規約（YAML 規約・ID/採番）・操作規約（results_manager.py サブコマンド・exit code）を確認する | `yaml-schema.md` |
| `test-cases.yaml` の構造・enum 値・revision 規則を確認する | `yaml-schema-cases.md` |
| `test-results.yaml` の構造・enum 値・status の使い分け・latest を確認する | `yaml-schema-results.md` |
| test-analyze（Phase 1.5）が生成するテスト対象理解の材料（`analysis.yaml` / `target-analysis.md`）のスキーマ・`source_availability` 縮退・リスク二軸を確認する | `yaml-schema-analysis.md` |
| test-environment（Phase 1.7）が生成するテスト用派生環境のマニフェスト（`environment.yaml`）のスキーマ・`applicability` 縮退・ライフサイクル（up / down / status）・コマンド規約形を確認する | `yaml-schema-environment.md` |
| 報告書（Excel / Markdown）の構成・スタイル・免責注記を確認する | `report-format.md` |
| NG 時の提出物（再現手順・検証データ・エビデンス）要件・二段バリデーション・機微情報マスキングを確認する | `evidence-policy.md` |
| 欠陥の severity（本番影響度）を判定する | `severity-policy.md` |
| 再テストの対象判定（full / ng-only / ids）・集計規則を確認する | `retest-policy.md` |
| 実績・エビデンス・報告書の配置パス / target-slug 解決 / エビデンス移送を行う | `data-locations.md` |
| Playwright MCP の登録・既存登録検出・起動オプション・正本ツールリストを確認する | `playwright-mcp.md` |
| Playwright Test（`.spec.ts` + フィクスチャ）の実行規約・`fixtures.yaml`（test-fixture 生成・Phase 1.6）のスキーマ・認証/モック/シードのパターンを確認する | `playwright-test.md` |
| エージェントの選定・起動・プロンプト組み立てを行う | `agents.md` |
| 実行時の共通規範（MCP ゲート・条件付き動的検証・SKIPPED・タイムアウト・テストデータ分離・非対話既定値）を確認する | `execution-policy.md` |
| 手動実施（`manual-assist` / `exploratory`）ケースの提示・聴取・人間提供エビデンス受領・探索的セッション規範・手順書/チャーターシート様式を確認する | `manual-execution.md` |
| venv を構築・削除する（全スキル共通の requirements.txt を含む） | `scripts/setup/`（`setup_venv.sh` / `teardown_venv.sh` / `requirements.txt`） |
| Python スクリプトをタイムアウト付きで実行する（任意利用のラッパー） | `scripts/run/run_via_job.sh` |
| エビデンスを外部共有・クリーンアップ用にアーカイブする | `scripts/run/archive_evidence.sh`（利用手順は `data-locations.md` 7 章） |

## SSOT 所有権一覧

各規範の**唯一の定義場所**。他ファイルは参照のみ行い、内容を複製しない。

| ファイル | SSOT 所有（唯一の定義場所） |
|---------|--------------------------|
| `CLAUDE.md` | references ナビゲーション（読み込みガイド） |
| `common-references.md` | 全 worker スキル（フェーズ 7 + 実行 6 の 13 スキル）共通の参照インデックス |
| `test-levels.md` | 8 テストレベルの定義・入口/出口基準・スキルマッピング・ケース ID プレフィクス・用語注記（ユニット/単体の独自区分）・IT-a/IT-b 入口基準とスタブポリシー・UAT の位置付け・性能/セキュリティのスコープ境界・スキル分割原理 |
| `yaml-schema.md` | 実績 YAML 共通の記述規約（YAML 記述規約・ID/採番規約）と操作規約（results_manager.py サブコマンド・exit code）。スキーマ定義群のハブ |
| `yaml-schema-cases.md` | `test-cases.yaml` の完全スキーマ（meta / cases[] / revision・承認・削除の規則） |
| `yaml-schema-results.md` | `test-results.yaml` の完全スキーマ（meta / runs[] / results[] / defect / latest / status の使い分け。enum 値のうち severity のみ severity-policy.md を参照し複製しない） |
| `yaml-schema-analysis.md` | `analysis.yaml`（test-analyze が生成する対象理解の材料）の完全スキーマ（meta / architecture / entry_points / dependency_summary / hotspots / existing_tests_summary / testability_findings / risk_register / attack_surface_summary / coverage_viewpoints / spec_divergence / change_impact / open_questions・`source_availability` 縮退・リスク二軸注記。product risk は severity-policy.md を複製しない） |
| `yaml-schema-environment.md` | `environment.yaml`（test-environment が生成するテスト用派生環境のマニフェスト）の完全スキーマ（meta / derived_from / derived_artifacts / project / services / endpoints / exec_forms / lifecycle / status・`applicability` 縮退・コマンド規約形。生成・更新は test-environment の LLM Write に限り、results_manager.py を経由しない別系統） |
| `report-format.md` | 報告書フォーマット（Excel シート構成・Markdown 章立て・スタイル・免責注記・latest 採用集計の参照） |
| `evidence-policy.md` | エビデンス・再現手順・検証データの必須要件（NG 時提出物）・二段バリデーション・機微情報マスキング方針 |
| `severity-policy.md` | **欠陥重要度（本番影響度）の enum 値 + 判定基準**（プラグイン内で唯一） |
| `retest-policy.md` | 再テストモード・status×モード対象判定マトリクス・回帰テスト非代替の明記・未承認ケースの扱い・最新 run 採用の集計規則 |
| `data-locations.md` | 実績・エビデンス・報告書の配置パス規約（`.claude/.local/plugins/deep-test/` 配下）・target-slug 解決フロー・エビデンス移送手順・保持/クリーンアップ方針 |
| `playwright-mcp.md` | Playwright MCP セットアップ・既存登録検出・起動オプション・出力先規約・正本ツールリスト（各スキル frontmatter の同期元） |
| `playwright-test.md` | Playwright Test（`.spec.ts` + フィクスチャ）実行規約・`fixtures.yaml` スキーマ（test-fixture 生成・Phase 1.6）・認証(storageState)/モック(route.fulfill)/シード/base(test.extend) のパターン規範 |
| `agents.md` | エージェント選定表・起動方式・プロンプト組み立て・共通注入事項・並列起動の原則 |
| `execution-policy.md` | 実行共通規範（MCP ゲート・条件付き動的検証・SKIPPED 記録・タイムアウト・テストデータ分離・環境安全・非対話既定値表） |
| `manual-execution.md` | 手動実行規範（`manual-assist` / `exploratory` の提示 3 要素・AskUserQuestion 聴取設計・人間提供エビデンスの受領/移送/マスキング適用手順・中断/resume・探索的セッション規範〔チャーター・タイムボックス・セッションシート・session_findings〕・非対話の手順書縮退・手順書/チャーターシート様式） |

## 禁止事項

- プラグイン直下・スキル直下の `README.md`（人間向け）をエージェント動作で参照すること
- 共通 references に個別スキル固有ロジックへの依存を追加すること（適用先スキルを示すポインタ記載は除く）
- severity の enum 値・判定基準を `severity-policy.md` 以外のファイルに複製すること（SSOT 違反）
- `test-results.yaml` を Edit/Write で直接編集すること（専用スクリプト経由に限る）
- 本ファイルのナビゲーション表・SSOT 所有権一覧を更新せずに references のファイル追加・改名を行うこと
