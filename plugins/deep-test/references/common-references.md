# worker スキル共通リファレンス（SSOT）

`deep-test` プラグインの全 worker スキル 13 種が共通参照するリファレンスの集約インデックス。
各スキルの SKILL.md は本ファイルを 1 行参照するだけで共通規範一式に到達できる。

> **位置付け**: `${CLAUDE_PLUGIN_ROOT}/references/common-references.md`（プラグイン共通 references）。
> 対象は worker スキル（フェーズスキル 7 + 実行スキル 6）。オーケストレータ `test` は制御専任のため本ファイルの参照契約の対象外（必要な references を直接参照する）。
> 本ファイル → 個別スキルへの依存は持たない（適用先スキルを示す一覧の記載は許容）。

---

## 1. 対象スキル（13 worker スキル）

| 区分 | スキル |
|------|-------|
| フェーズスキル（7） | `test-setup` / `test-analyze` / `test-fixture` / `test-environment` / `test-design` / `test-review` / `test-report` |
| 実行スキル（6） | `test-run-unit` / `test-run-functional` / `test-run-integration` / `test-run-scenario` / `test-run-performance` / `test-run-security` |

## 2. 全スキル共通（常時参照）

| ファイル | 内容 | 主な利用タイミング |
|---------|------|-------------------|
| `test-levels.md` | 8 テストレベル定義・入口/出口基準・ケース ID プレフィクス・用語注記 | テストレベルに言及・判定する全処理 |
| `data-locations.md` | target-slug 解決・実績/エビデンス/報告書の配置パス（`.claude/.local/plugins/deep-test/` 配下） | データの読み書き前 |
| `execution-policy.md` | 実行共通規範（条件付き動的検証・SKIPPED 記録・非対話既定値表） | 実行可否の分岐判断・非対話モードでの既定値適用時 |

## 3. 場面別参照

### 3.1 設計時（`test-design`）

| ファイル | 利用目的 |
|---------|---------|
| `test-levels.md` | レベル選定・ケース ID プレフィクス付与・入口/出口基準のケース反映 |
| `yaml-schema.md` | YAML 記述規約・ケース ID/run ID の採番規約（共通規約ハブ） |
| `yaml-schema-cases.md` | `test-cases.yaml` の生成・revision 規則・enum 値の遵守 |
| `agents.md` | test-architect の起動・プロンプト組み立て |
| `execution-policy.md` | テストデータ分離（preconditions / postconditions 設計）・破壊的操作の明示 |

### 3.2 レビュー時（`test-review`）

| ファイル | 利用目的 |
|---------|---------|
| `agents.md` | 文脈別（設計 / 結果）のエージェント選定・並列起動・共通注入事項 |
| `test-levels.md` | 網羅性・レベル適合性の判定基準 |
| `severity-policy.md` | severity 妥当性の検証基準（結果文脈） |
| `evidence-policy.md` | 再現手順・検証データ・エビデンス要件の検証基準（結果文脈） |
| `yaml-schema-cases.md` | `review_status` の遷移規則・ケース構造の妥当性確認 |

### 3.3 実行時（`test-run-*` 6 スキル共通）

| ファイル | 利用目的 |
|---------|---------|
| `execution-policy.md` | 実行規範全般（タイムアウト・環境安全・エビデンス自動収集・SKIPPED/blocked の使い分け） |
| `test-levels.md` | 担当レベルの入口基準充足確認・主な確認観点 |
| `playwright-mcp.md` | MCP ツール利用規約・出力先（`test-run-unit` 単独実行では参照不要） |
| `evidence-policy.md` | fail 時の defect 3 点セット（再現手順・検証データ・エビデンス）収集要件・機微情報の扱い |
| `severity-policy.md` | fail 時の severity 判定 |
| `yaml-schema-results.md` | 返却する中間結果の status enum・defect フィールド定義・status の使い分け |
| `data-locations.md` | エビデンス移送手順（run/case 単位フォルダへの move） |
| `manual-execution.md` | `manual-assist` / `exploratory` ケースの提示・聴取・エビデンス受領・記録規約（手動実行の SSOT） |

### 3.4 報告時（`test-report`）

| ファイル | 利用目的 |
|---------|---------|
| `report-format.md` | Excel / Markdown の構成・スタイル・免責注記 |
| `evidence-policy.md` | 報告書生成前の最終バリデーション・機微情報マスキング |
| `retest-policy.md` | latest（ケースごとの最新 run 結果）採用の集計規則・ng-only 非代替の注記 |
| `severity-policy.md` | NG 一覧の severity 表記 |
| `agents.md` | evidence-auditor の起動 |
| `data-locations.md` | エビデンスの相対パス参照・報告書の出力先 |

### 3.5 セットアップ時（`test-setup`）

| ファイル | 利用目的 |
|---------|---------|
| `playwright-mcp.md` | MCP 登録・既存登録検出（重複登録禁止）・起動オプション・正本ツールリスト |
| `data-locations.md` | Playwright 出力先規約・target-slug 配下の初期化 |
| `execution-policy.md` | ツール利用可否判定の結果記録方法（後続の MCP ゲート判定材料） |

### 3.6 解析時（`test-analyze`）

| ファイル | 利用目的 |
|---------|---------|
| `yaml-schema-analysis.md` | `analysis.yaml` の生成・スキーマ遵守（`source_availability` 縮退・リスク二軸） |
| `data-locations.md` | `analysis.yaml` / `target-analysis.md` の配置先・target-slug 解決 |
| `agents.md` | source-analyst の起動・プロンプト組み立て |

### 3.7 フィクスチャ設計時（`test-fixture`）

| ファイル | 利用目的 |
|---------|---------|
| `playwright-test.md` | `fixtures.yaml` スキーマ・Playwright Test 実行規約・認証(storageState)/モック(route.fulfill)/シード/base(test.extend) のパターン規範 |
| `yaml-schema-analysis.md` | 材料として消費する `analysis.yaml`（entry_points / external_dependencies / attack_surface_summary）のスキーマ |
| `data-locations.md` | `fixtures.yaml` の配置先・target-slug 解決・SUT テストコードは deep-test 管理外である旨 |
| `yaml-schema-cases.md` | `automation: playwright-test` / `cases[].fixtures` の定義（test-design への引き渡し前提） |
| `agents.md` | fixture-architect の起動・プロンプト組み立て |
| `execution-policy.md` | playwright-test の実行 / SKIPPED 規範・テストデータ分離 |

### 3.8 環境構築時（`test-environment`）

| ファイル | 利用目的 |
|---------|---------|
| `yaml-schema-environment.md` | `environment.yaml` の生成・スキーマ遵守（`applicability` 縮退・ライフサイクル状態・コマンド規約形・enum 値） |
| `yaml-schema-analysis.md` | 材料として消費する `analysis.yaml`（`architecture.build_run` / `dependency_summary.external_dependencies` / `meta.target_type` / `entry_points`）のスキーマ |
| `data-locations.md` | `environment.yaml` / `environment/` 配下の配置先・target-slug 解決・SUT docker 資産は read-only である旨 |
| `execution-policy.md` | Docker デーモン利用不可時の縮退（skipped）・非対話既定値（environment up の可否・health 未達時の扱い） |
| `agents.md` | env-architect の起動・プロンプト組み立て |

## 4. 実行スキル共通契約（結果の返却）

実行スキル 6 種は以下の共通契約に従う。

- 実行結果は**中間データとして返却するのみ**。`test-results.yaml` への書き込みはオーケストレータ `test` が専用スクリプト経由で一元実行する（並列競合防止・LLM 直接編集禁止）
- 返却する中間データの項目は `yaml-schema-results.md` の results 項目（status / reason / executed_by / duration_sec / actual / evidence / defect / extras）に対応させる
- 実行手段が利用不可（MCP 未ロード・テストランナー不在・外部接続不可）の場合は実行を偽装せず `skipped` または `blocked` + reason で返却する（使い分けは `execution-policy.md`）
- fail 時は defect 3 点セット（再現手順・検証データ・エビデンス）を `evidence-policy.md` に従い**その場で**収集して返却する（一次バリデーションはオーケストレータの record 時に行われる）
- エビデンスはステップ実行直後に `data-locations.md` の移送手順で run/case 単位のフォルダへ移送する

## 5. 適用契約

本ファイルは worker スキル 13 種が共通参照するリファレンスのインデックスであり、各 SKILL.md からの参照は本ファイル経由の 1 行に集約する。
規範の改訂は各 SSOT ファイル側で行い、本ファイルは参照先の追加・変更時のみ更新する（SSOT 所有権は `CLAUDE.md` の一覧を参照）。
