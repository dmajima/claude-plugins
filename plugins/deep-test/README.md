# deep-test

テスト設計→レビュー→実施→結果レビュー→報告→再テストのフルライフサイクルを、テストレベル別特化スキルとマルチエージェントレビューで支援する観点別テストプラグインです。日本の SI 実務で使われる 8 テストレベル（ユニット/単体/内部結合/外部結合/システム/受入(UAT)/性能/セキュリティ）に対応し、Playwright MCP による実アプリ動作・ユーザー目線のテストを重視します。テスト実績は YAML で永続化され、全件・NG のみ・ID 指定の再テストと、Excel / Markdown の 1 ファイル報告書生成ができます。人手確認が不可欠なケース（manual-assist）とチャーターベースの探索的テスト（exploratory）も自動実行と同一の実績管理に統合し、対話時は確認・探索セッションを支援、非対話時は手動手順書（チャーターシート）の自動生成に縮退します。報告書では実行主体（自動 / 手動）を区別して集計します。

なお、コードレビュー中の差分限定ユニットテスト実行はコードレビュー系プラグインの責務であり、本プラグインはプロジェクト全体のテストライフサイクル管理を担います。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 導入手順

### 前提

- Claude Code がインストール済み
- 依存プラグインなし

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install deep-test@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. 必要に応じてブランチ・タグ切替
cd <local-path>
git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install deep-test@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": {
        "type": "github",
        "repo": "dmajima/claude-plugins"
      },
      "autoUpdate": true
    }
  }
}
```

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できます。

### D. 依存関係のインストール

依存プラグインはありません。

**任意依存プラグイン**

以下のプラグインがインストールされていると追加機能が利用できます。未インストールでも全機能が動作します。

- `credentials-manager@dmajima-claude-plugins`: IT-b（外部結合テスト）で認証が必要な外部 API を確認する際、認証情報の解決に利用する。未インストールでも動作するが、認証が必要なケースは API 補助確認未実施として記録される

**Python 等の外部ツール依存**

スキル内で以下の外部ツールを使用します。利用者環境に導入されている前提です:

- Python 3.9+（実績 YAML 操作・報告書生成スクリプトの実行。venv はセッション作業領域に自動構築）
- Node.js / npx（Playwright MCP の登録・起動に使用）
- Playwright MCP（`test-setup` スキルが `claude mcp add -s local` で登録を案内。登録後は Claude Code の再起動が必要。他ツールが `playwright` 名で MCP 登録済みの場合は test-setup が検出して再利用します〔重複登録しません〕）
- テストランナー（ユニットテスト実行時のみ。対象プロジェクト側の pytest / jest / vitest / dotnet test 等を自動検出）
- 負荷計測ツール（性能テストの多重負荷計測時のみ。k6 等を検出した場合に限り使用、なければ該当ケースは skipped 記録）
- docker CLI / Docker Compose v2（テスト用派生環境の生成・起動時のみ〔Phase 1.7〕に使用する**任意依存**。未導入・利用不可の場合は環境構築を縮退〔no-op 記録〕し、環境前提のケースは skipped 記録の材料になる）

### 動作確認

自然言語で「deep-test でテストしたい」と入力し、オーケストレータ（`test` スキル）がテスト対象の確認（target-slug の選択・新規作成）から開始することを確認します。対象確認の質問が表示されれば導入成功です（この時点ではテストはまだ実行されません）。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `test` | スキル | オーケストレータ。ライフサイクル全体の制御（モード判定・フェーズ委譲・ゲート判定・実績記録・再テスト対象選択） |
| `test-setup` | スキル | 実行環境の構築・検証（Playwright MCP 登録・テストランナー検出・venv） |
| `test-analyze` | スキル | テスト対象ソースを read-only で理解し解析材料を生成（analysis.yaml / target-analysis.md・Phase 1.5・test-design の前段） |
| `test-fixture` | スキル | Playwright フィクスチャ基盤（認証 storageState / API モック / シード / base）の作成・拡充（fixtures.yaml 生成・analysis.yaml 消費・Phase 1.6） |
| `test-environment` | スキル | Docker 派生テスト環境の provision / up / down / status（SUT の docker 資産から compose.test.yml / .env.test を非破壊生成・environment.yaml 管理・analysis.yaml 消費・Phase 1.7） |
| `test-design` | スキル | テスト対象分析→テスト計画→テストケース設計（test-cases.yaml 生成・revision 管理） |
| `test-review` | スキル | テスト成果物の多観点レビュー（設計文脈: 網羅性・実現性・ユーザー目線 / 結果文脈: 欠陥分析・severity 検証） |
| `test-run-unit` | スキル | ユニットテスト実行（pytest / jest / dotnet test 等の検出・実行・解析） |
| `test-run-functional` | スキル | 単体（機能）テスト実行（Playwright による画面・機能単位の実動作確認） |
| `test-run-integration` | スキル | 内部結合・外部結合テスト実行（モジュール間・外部 IF 連携、スタブポリシー付き） |
| `test-run-scenario` | スキル | システムテスト・UAT 観点シナリオ実行（業務シナリオ E2E） |
| `test-run-performance` | スキル | 性能テスト実行（単一セッション応答時間計測 + 条件付き負荷ツール連携） |
| `test-run-security` | スキル | セキュリティテスト実行（OWASP 観点の動的チェック） |
| `test-report` | スキル | 実績 YAML からの報告書生成（Excel / Markdown・1 ファイル）+ エビデンス完全性バリデーション |
| `/deep-test:test` | コマンド | フルフロー起動（設計→レビュー→実施→結果レビュー→報告） |
| `/deep-test:test-retest` | コマンド | 再テスト起動（full / ng-only / ids / resume） |
| `/deep-test:test-report` | コマンド | 報告書のみ再生成 |
| `/deep-test:test-fixture` | コマンド | フィクスチャ基盤の単独構築・拡充（Phase 1.6・実行はしない） |
| `/deep-test:test-environment` | コマンド | テスト用派生環境の単独操作（provision / up / down / status・Phase 1.7・テスト実行はしない） |
| `source-analyst` | エージェント | 解析材料の網羅性・根拠妥当性の自己チェック |
| `fixture-architect` | エージェント | フィクスチャ設計の妥当性・再利用性・分離・書き込み境界・認証情報ハードコードの自己チェック |
| `env-architect` | エージェント | 派生環境の分離妥当性・read-only 境界・秘匿値の非出力・本番誤爆疑義・teardown 完全性の自己チェック |
| `test-architect` | エージェント | テスト戦略・レベル選定・計画妥当性の評価 |
| `coverage-reviewer` | エージェント | 網羅性レビュー（要件・境界値・同値分割・異常系） |
| `feasibility-reviewer` | エージェント | 実行可能性・自動化適合性・環境依存リスクの評価 |
| `user-perspective-reviewer` | エージェント | ユーザー目線・UAT 観点・業務シナリオ妥当性の評価 |
| `defect-analyst` | エージェント | NG 分析・原因分類・再現手順完全性・severity 妥当性の検証 |
| `evidence-auditor` | エージェント | エビデンス完全性・機微情報マスキング・報告書転載可否の監査 |

## 使い方

### スラッシュコマンド

```text
/deep-test:test                        # フルフロー（設計→レビュー→実施→結果レビュー→報告）
/deep-test:test spec=docs/spec.md     # 仕様書を入力にテスト設計から実行
/deep-test:test levels=unit,functional # 対象テストレベルを指定
/deep-test:test design-only            # テスト設計→設計レビューまで（実行しない）
/deep-test:test run-only levels=unit   # 実行フェーズのみ（levels= 指定必須）
/deep-test:test-retest ng-only         # NG（fail/blocked/skipped）のみ再テスト
/deep-test:test-retest full            # 全件再テスト
/deep-test:test-retest ids=TC-FUNC-001,TC-SYS-002  # ID 指定再テスト
/deep-test:test-retest resume          # 中断した run の続きから再開
/deep-test:test-report                 # 実績 YAML から報告書のみ再生成
```

### 自然言語

| 発話例 | 起動 |
|-------|-----|
| 「このアプリのテストをして」「テスト計画から報告まで一式お願い」 | `test`（フルフロー） |
| 「テストケースを設計して」 | `test`（design-only）または `test-design` |
| 「テスト対象を解析して」「解析材料を作って」 | `test`（analyze フェーズ）または `test-analyze` |
| 「フィクスチャ基盤を作って」「認証 storageState を用意して」「API モックを追加して」 | `test`（fixture フェーズ）または `test-fixture` |
| 「テスト用の Docker 環境を作って」「テスト用コンテナ環境を起動して」「テスト用コンテナ環境を片付けて」 | `test`（environment フェーズ）または `test-environment` |
| 「手動テストも混ぜて」「目視確認のケースも入れて」 | `test`（フルフロー。`automation: manual-assist` のケースを対話で人手確認・非対話時は手順書生成に縮退） |
| 「探索的テストをやりたい」「探索セッションで気になるところを見たい」 | `test`（フルフロー。`automation: exploratory` のチャーターベース探索セッションを実施・記録） |
| 「前回 NG だったテストだけ再実行して」 | `test`（retest ng-only） |
| 「テスト報告書を Excel で作って」 | `test`（report-only） |
| 「テストツールチェーンを準備して」 | `test-setup` |

### 実行フロー（フルフロー時）

```text
setup 確認 → 解析（Phase 1.5） → フィクスチャ基盤（Phase 1.6） → 環境構築（Phase 1.7） → テスト設計 → 設計レビュー（3 エージェント並列）
  → 人間承認ゲート → MCP ゲート
  → テスト実施（レベル順逐次・エビデンス自動収集）
  → 結果レビュー（2 エージェント並列） → 報告書生成
```

- 設計レビューで Critical / High 指摘がある場合は実行フェーズをブロックし、修正ループに入ります
- docker 資産があるプロジェクトでは Phase 1.7 で非破壊のテスト用派生環境（compose.test.yml / .env.test）を provision し、テスト実施の直前に up・結果レビュー PASS 後に down します（資産なし / docker 利用不可の場合は縮退記録のみでフローは止まりません）
- テスト NG（fail）時は再現手順・検証データ・エビデンスの 3 点セットが必須で、欠落した状態では報告書を生成できません（二段バリデーション）
- テスト実績は `.claude/.local/plugins/deep-test/{target-slug}/` に YAML で永続化され、再テスト・報告書再生成の基盤になります

### 初回実行時の注意

- Playwright MCP を新規登録した場合は Claude Code の再起動が必要です。再起動ハンドオフの案内に従って再起動し、「resume」と入力すると中断位置から再開できます
- テスト実行前に人間承認ゲートがあり、実行対象のケース数・想定時間を確認してから実行へ進みます（`--non-interactive` 時はスキップ）
- フルフローはケース数に応じて時間がかかります（目安: 10 ケースで 15 分程度）

## ファイル構成

```text
plugins/deep-test/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── LICENSE
├── commands/
│   ├── test.md                     # フルフロー起動
│   ├── test-retest.md              # 再テスト起動
│   ├── test-report.md              # 報告書再生成
│   ├── test-fixture.md             # フィクスチャ基盤の単独構築・拡充
│   └── test-environment.md         # テスト用派生環境の単独操作
├── agents/                         # 共有エージェント（9 種）
│   ├── source-analyst.md
│   ├── fixture-architect.md
│   ├── env-architect.md
│   ├── test-architect.md
│   ├── coverage-reviewer.md
│   ├── feasibility-reviewer.md
│   ├── user-perspective-reviewer.md
│   ├── defect-analyst.md
│   └── evidence-auditor.md
├── references/                     # プラグイン共通規範（ナビ CLAUDE.md + SSOT 17 ファイル + 人間向け README）+ 共通スクリプト
│   ├── CLAUDE.md                   # ナビゲーション
│   ├── README.md                   # 人間向けインデックス（Claude 動作では不参照）
│   ├── common-references.md        # worker スキル共通参照インデックス
│   ├── test-levels.md              # 8 テストレベル定義
│   ├── yaml-schema.md              # 実績 YAML 共通規約・操作規約（スキーマハブ）
│   ├── yaml-schema-cases.md        # test-cases.yaml スキーマ
│   ├── yaml-schema-results.md      # test-results.yaml スキーマ
│   ├── yaml-schema-analysis.md     # analysis.yaml スキーマ
│   ├── yaml-schema-environment.md  # environment.yaml スキーマ
│   ├── severity-policy.md          # 欠陥重要度基準
│   ├── retest-policy.md            # 再テスト規約
│   ├── data-locations.md           # データ配置規約
│   ├── execution-policy.md         # 実行共通規範（ゲート・条件付き動的検証）
│   ├── manual-execution.md         # 手動実行規範（manual-assist / exploratory・探索的セッション・手順書様式）
│   ├── playwright-mcp.md           # Playwright MCP 利用規約
│   ├── playwright-test.md          # Playwright Test 実行規約・fixtures.yaml スキーマ（Phase 1.6）
│   ├── evidence-policy.md          # エビデンス・NG 時提出物規約
│   ├── report-format.md            # 報告書フォーマット
│   ├── agents.md                   # エージェント運用定義
│   └── scripts/                    # プラグイン共通スクリプト
│       ├── setup/                  # venv 構築・削除（requirements.txt 含む。全スキル共通・一元管理）
│       └── run/                    # run_via_job.sh（Python 実行ラッパー）・archive_evidence.sh（エビデンスアーカイブ）
└── skills/
    ├── test/                       # オーケストレータ（+ references/scripts/results/results_manager.py）
    ├── test-setup/
    ├── test-analyze/
    ├── test-fixture/
    ├── test-environment/
    ├── test-design/
    ├── test-review/
    ├── test-run-unit/
    ├── test-run-functional/
    ├── test-run-integration/
    ├── test-run-scenario/
    ├── test-run-performance/
    ├── test-run-security/
    └── test-report/                # 報告書生成（+ references/scripts/report/ の生成スクリプト）
```

各スキルディレクトリは `SKILL.md`（Claude が参照するスキル定義）、`README.md`（人間向け）、`references/`（スキル固有手順）、`evals/`（期待挙動ケース）で構成されます。

## テスト実績データ

| データ | 場所 | 説明 |
|-------|------|------|
| 解析材料（機械可読） | `.claude/.local/plugins/deep-test/{target-slug}/analysis.yaml` | test-analyze が生成（Phase 1.5） |
| 解析材料（人間可読） | `.claude/.local/plugins/deep-test/{target-slug}/target-analysis.md` | test-analyze が生成（Phase 1.5） |
| フィクスチャ基盤マニフェスト | `.claude/.local/plugins/deep-test/{target-slug}/fixtures.yaml` | test-fixture が生成（Phase 1.6） |
| 派生環境マニフェスト | `.claude/.local/plugins/deep-test/{target-slug}/environment.yaml` | test-environment が生成（Phase 1.7） |
| 派生環境の成果物 | `.claude/.local/plugins/deep-test/{target-slug}/environment/` | compose.test.yml / .env.test / logs/（test-environment が生成・Phase 1.7） |
| テスト計画 | `.claude/.local/plugins/deep-test/{target-slug}/test-plan.md` | test-design が生成 |
| テストケース | `.claude/.local/plugins/deep-test/{target-slug}/test-cases.yaml` | revision 管理・review 承認制 |
| テスト実績 | `.claude/.local/plugins/deep-test/{target-slug}/test-results.yaml` | run 履歴の追記型 + latest 集計 |
| エビデンス | `.claude/.local/plugins/deep-test/{target-slug}/evidence/{run_id}/{case_id}/` | スクリーンショット・ログ・セッションシート（探索的テスト） |
| 手動手順書 | `.claude/.local/plugins/deep-test/{target-slug}/manual/` | manual-assist の実施指示書・exploratory のチャーターシート（非対話時・「後で実施」時に自動生成。再生成可能な派生物） |
| 報告書 | セッション作業領域直下 | Excel / Markdown（実績 YAML から何度でも再生成可能） |

## カスタマイズ

| 編集ポイント | ファイル |
|------------|---------|
| テストレベルの定義・観点 | `references/test-levels.md` |
| 欠陥重要度の判定基準 | `references/severity-policy.md` |
| 報告書のシート構成・スタイル | `references/report-format.md` + `skills/test-report/references/scripts/report/` |
| エビデンス必須要件 | `references/evidence-policy.md` |
| タイムアウト・非対話既定値 | `references/execution-policy.md` |
| レビューエージェントの評価観点 | `agents/*.md` |

## ライセンス

[MIT License](LICENSE) の下で配布されています。
