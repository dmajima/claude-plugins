# code-review スキル（オーケストレーター）

`deep-code-review` プラグイン配下の **観点別レビュースキル** を統括するオーケストレーター。
モード選択（標準/簡易）・スコープ確定・観点別スキルへの並列委譲・結果統合・最終判定（Verdict）を担当する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 役割

オーケストレーターのみが担当する責務:

| 責務 | 詳細 |
|------|------|
| モード選択 | 標準（impl / testing / security / arch / frontend）/ 簡易（impl / testing / security のみ）の判定 |
| スコープ確定 | PR / ブランチ / ファイルの判定。比較ブランチの自動判定（develop > main > master） |
| プロジェクト規約読込 | `CLAUDE.md` / `.claude/rules/` / `.editorconfig` 等の読み込みと要約生成（`project-rules-summary`） |
| 仕様書サマリ生成 | `spec=<path>` 引数指定時に仕様書を読み込み要約 |
| 観点別スキル委譲 | `Skill` ツールで並列起動 |
| 結果統合 | 各観点別スキルの中間レポートを集約 |
| 重複排除・優先度ランキング | 同一指摘のマージ、重要度の高い順に並べ替え |
| Verdict 判定 | Ready to Merge / Needs Attention / Needs Work |
| 統合サマリ出力 | 集計セクション（実施日時・比較ブランチ・参照規約・参照仕様書）を含む最終レポート生成 |

## 使い方

`code-review` はオーケストレーターのため、通常はユーザーが直接名指しせず、自然言語フレーズまたは `pr-review` からの委譲で自動起動する。

### トリガーフレーズ例

```
このブランチをレビューして
差分をレビューして
main との差分をレビューして
src/Order/Order.cs をレビューして
セキュリティと実装観点でレビューして
```

### スラッシュコマンド

| コマンド | 動作 |
|---------|------|
| `/code-review-standard [scope]` | 標準モード（最大 5 観点別スキル動員・差分内容により一部省略） |
| `/code-review-quick [scope]` | 簡易モード（impl / testing / security の必須トリオ） |

### 入力 → 出力の流れ

1. スコープ確定（PR / ブランチ差分 / ファイル指定）と比較ブランチ自動判定
2. 言語・FW 検出 → 観点別スキルへ並列委譲（`project-rules-summary` / `language-profiles` を引き渡す）
3. 中間レポート統合 → 信頼度 60 未満の足切り → 重複排除・プロファイルアンカー照合
4. 統合サマリ（Issues / Suggestions / Scope-out の 3 分類）+ Verdict（Ready to Merge / Needs Attention / Needs Work）を出力

## 観点別スキルへの委譲

| 観点別スキル | 動員エージェント | 必須/条件付き |
|-------------|----------------|-------------|
| `code-review-implementation` | implementation-engineer / linter-static-analysis / performance-reviewer | 必須トリオ（標準・簡易） |
| `code-review-testing` | test-engineer / test-runner | 必須トリオ（標準・簡易） |
| `code-review-security` | security-engineer / dependency-safety | 必須トリオ（標準・簡易） |
| `code-review-architecture` | architect / dba | 標準のみ・差分内容に応じて省略可 |
| `code-review-frontend` | web-designer | 標準のみ・UI 変更ありの場合のみ |

## ファイル構成

```
skills/code-review/
├── SKILL.md                          # スキル定義（Claude が読み込むエントリポイント）
├── README.md                         # 本ファイル（人間向け）
└── references/                       # オーケストレーター固有のリファレンス
    ├── CLAUDE.md                     # 読み込みガイド（優先度・構成）
    ├── flow/                         # 実行フロー
    │   ├── flow.md                   # Step 0-P〜8.5 メインフロー
    │   ├── mode-selection.md         # Step 0: モード選択
    │   ├── scope-detection.md        # Step 1: スコープ確定
    │   └── team-selection.md         # Step 3.5-4T: Agent Teams
    ├── state/                        # 状態管理
    │   ├── state-management.md       # state.yaml 管理
    │   ├── inputs-management.md      # inputs フォルダ管理
    │   └── code-trustworthiness.md   # コード信頼性原則（U14）
    ├── output/                       # 出力フォーマット
    │   └── output-format.md          # Verdict 判定・Finding ID
    ├── template/                     # テンプレート（業務単位で細分化）
    │   ├── output/
    │   │   └── review-summary.md     # 統合サマリテンプレート
    │   └── state/
    │       └── state_template.yaml   # state.yaml テンプレート
    └── quality/                      # 達成チェック
        └── checklist.md              # U1-U16 + C1-C25
```

> 共有エージェント定義（10種）と共通リファレンス（agents.md / severity-ranking.md）は **プラグインルート** にあり、観点別スキルとも共有。

## カスタマイズ・拡張

### モード追加（例: 詳細モード）

`references/flow/mode-selection.md` の `AskUserQuestion` 選択肢を変更し、動員する観点別スキルを定義する。

### 比較ブランチの優先順位変更

`references/flow/scope-detection.md` の自動判定ロジックを変更する（既定: develop > main > master）。

### 出力フォーマットの変更

`references/output/output-format.md` と `references/template/output/review-summary.md` を編集する。
判定ルール（Verdict）を変える場合は `output/output-format.md` のセクション 3 を更新。

### 観点別スキルの追加

新しい観点（例: `code-review-cloud-infra`）を追加したい場合:

1. `${CLAUDE_PLUGIN_ROOT}/skills/code-review-<新観点>/SKILL.md` を作成
2. 新観点が使うエージェント定義を `${CLAUDE_PLUGIN_ROOT}/agents/` に追加
3. 本スキルの `SKILL.md` の委譲表に追加
4. `${CLAUDE_PLUGIN_ROOT}/references/agents.md` の選定ルールを更新

### プロジェクト固有規約の取り扱い

オーケストレーターは Step 2 で対象リポジトリの規約を読み込み、要約（`project-rules-summary`）として観点別スキルに渡す。
固有規約はプラグイン側に保持しない。

| 探索対象 | 用途 |
|---------|------|
| `CLAUDE.md` / `.claude/CLAUDE.md` | プロジェクト全体の方針・規約 |
| `.claude/rules/**/*.md` | 細分化されたルール |
| `CONTRIBUTING.md` / `docs/` 配下 | コントリビューションガイド・スタイルガイド |
| `.editorconfig` / `.eslintrc*` / `.prettierrc*` / `.stylelintrc*` 等 | 整形・Linter 設定 |

## スコープ外（本スキルが行わないこと）

- 個別エージェントの直接起動（観点別スキルの責務）
- ビルド・Linter・テスト・脆弱性スキャンの実行（観点別スキル内のエージェントが担当）
- E2E / 結合 / ブラウザ / 性能テストの実行（プラグイン全体のスコープ外）
- バグ修正の実装（指摘提示のみ）
- リリース可否の最終決定（Verdict は技術観点）

## 設計原則

- **責務の階層化**: オーケストレーター（本スキル）→ 観点別スキル → エージェント の3階層
- **並列処理**: 観点別スキルを Independent 型で並列起動
- **モード切替**: 規模・コスト制約に応じて簡易モード（impl / testing / security の3観点）にスケールダウン可能
- **重複統合**: 同一指摘は 1 件にまとめ、最も重い重要度を採用
- **判定の保守性**: より厳しい側を採用（Critical/High が1件でも Needs Work、test-runner RED で Needs Work）
- **未確認事項の明示**: 動的検証 SKIPPED 等を必ず記載、「未実施」を「問題なし」と書かない
