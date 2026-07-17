# 参加エージェントの選定とプロンプト構成

`deep-code-review` プラグイン配下のスキルが参加させるエージェントの選定ルール・呼び出し方・プロンプト組み立て方を定義する。

> **構造**: エージェントの直接起動は **観点別スキル** が担当する。`code-review` オーケストレーターは観点別スキルを Skill ツール経由で並列起動し、各観点別スキルが自分の担当エージェントを並列起動する。
>
> | 観点別スキル | 起動するエージェント |
> |-------------|---------------------|
> | `code-review-implementation` | implementation-engineer / linter-static-analysis / performance-reviewer |
> | `code-review-testing` | test-engineer / test-runner |
> | `code-review-security` | security-engineer / dependency-safety |
> | `code-review-architecture` | architect / dba |
> | `code-review-frontend` | web-designer |
>
> **補助スキル**: 観点別レビューとは別軸の **推論・判定支援スキル** が追加されている。これらは `pr-review` 等の I/O アダプタ層から Skill ツール経由で呼び出される。
>
> | 補助スキル | 役割 | 主な呼び出し元 |
> |-----------|------|---------------|
> | `code-review-spec-inference` | PR description / コメント / 外部リンクから期待挙動を推論（仕様書代替） | `pr-review` Step 3.5 |

---

## 1. 参加エージェント一覧

プラグインルートの `agents/` に配置した共有エージェント定義を `subagent_type` で指定して呼び出す。

| ID | subagent_type | 役割 | モード | 動的検証 |
|----|--------------|------|------|------|
| impl | `implementation-engineer` | コード品質（正確性・Quality/Style・Simplification） | 簡易・標準 | — |
| test | `test-engineer` | ユニットテストコード品質（網羅性・エッジケース・モック過剰） | 簡易・標準 | — |
| sec | `security-engineer` | セキュリティ（OWASP/STRIDE） | 簡易・標準 | — |
| linter | `linter-static-analysis` | コーディング規約・整形・型違反の検出（**ビルド・Linter コマンド実行可**） | 標準のみ | ビルド / Linter / 整形チェッカ |
| runner | `test-runner` | プロジェクトのユニットテスト実行 | 標準のみ | ユニットテスト |
| perf | `performance-reviewer` | 性能（N+1・ブロッキング・メモリ・状態管理機構肥大化） | 標準のみ | — |
| dep | `dependency-safety` | 依存関係・破壊的変更・マイグレーション・設定階層整合・**脆弱性スキャン実行可** | 標準のみ | 脆弱性スキャン |
| arch | `architect` | システム設計・技術的負債 | 標準のみ | — |
| dba | `dba` | DB スキーマ・SQL・マイグレーション安全性 | 標準のみ（DB 変更あり時） | — |
| web | `web-designer` | HTML / CSS / アクセシビリティ / レスポンシブ | 標準のみ（UI 変更あり時） | — |

### 動的検証の実行可否

`linter-static-analysis` / `test-runner` / `dependency-safety` の 3 エージェントは、対応する Bash 権限が `allowed-tools` に追加されている場合に限り実コマンドを実行する。
追加すべき Bash 権限の例とコマンドは `${CLAUDE_PLUGIN_ROOT}/skills/code-review/SKILL.md` の「動的検証コマンドの追加方法」を参照。
権限が追加されていない場合は SKIPPED として記録し、「未実施」を「問題なし」と書かない設計。

---

## 2. 選定ルール

> **粒度**: モードによる動員制御は **観点別スキル単位**。各観点別スキル内のエージェントは、そのスキルが起動された場合は通常通り並列起動される（動的検証エージェントは権限がなければ SKIPPED）。

### 2.1 簡易モード（観点別スキル3種）

- 動員観点別スキル: `code-review-implementation` / `code-review-testing` / `code-review-security`
- 内訳エージェント: 各スキル内のエージェント全員（最大7種：impl + linter + perf + test + runner + sec + dep）
- 観点別スキル単位での動的絞り込みは行わない

### 2.2 標準モード（観点別スキル5種、差分内容に応じて省略あり）

#### 必ず起動

- `code-review-implementation` / `code-review-testing` / `code-review-security`

#### 動的に省略可

| 観点別スキル | 省略条件（オーケストレーターが判定） |
|------------|---------|
| `code-review-architecture` | アーキテクチャに影響しない単純変更（コメント追記・タイプミス修正 等）のみ かつ DB 変更なし |
| `code-review-frontend` | HTML / テンプレート / CSS / 静的アセット / JavaScript の変更が一切ない場合 |

#### 観点別スキル内部のエージェント省略

| エージェント | 省略条件 |
|------------|---------|
| arch | アーキテクチャに影響しない単純変更（コメント追記・タイプミス修正 等）のみの場合 |
| dba | SQL / DB スキーマ / マイグレーション変更が一切ない場合 |
| web | HTML / テンプレート / CSS / 静的アセットの変更が一切ない場合 |
| runner | プロジェクトにテスト基盤が存在しない、または環境的に実行不可能な場合（その場合 SKIPPED として記録のみ） |

#### 起動しない条件（モード共通）

| 条件 | 理由 |
|------|------|
| 単純なタイプミス・コメント修正のみ | 多角レビューのオーバーヘッドが見合わない（簡易モードを推奨） |
| ドキュメント・README のみの変更 | コード品質観点が無関係（簡易モードでも省略可） |

ユーザーが明示的に「フルレビュー」「全エージェント動員」を要求した場合は、上記の動的省略を適用せず標準モード全動員とする。

---

## 3. 起動方法

### 3.1 並列起動（必須）

選定したエージェントは **1 メッセージ内で複数の Agent ツールコール** として並列発行する。

```
# 標準モード（典型例）
Agent({ subagent_type: "implementation-engineer", description: "実装レビュー", prompt: "..." })
Agent({ subagent_type: "test-engineer",            description: "テストレビュー", prompt: "..." })
Agent({ subagent_type: "security-engineer",        description: "セキュリティレビュー", prompt: "..." })
Agent({ subagent_type: "linter-static-analysis",   description: "Linter/静的解析", prompt: "..." })
Agent({ subagent_type: "test-runner",              description: "ユニットテスト実行", prompt: "..." })
Agent({ subagent_type: "performance-reviewer",     description: "性能レビュー", prompt: "..." })
Agent({ subagent_type: "dependency-safety",        description: "依存・デプロイ安全性", prompt: "..." })
Agent({ subagent_type: "architect",                description: "アーキテクチャレビュー", prompt: "..." })
Agent({ subagent_type: "dba",                      description: "DB レビュー", prompt: "..." })
Agent({ subagent_type: "web-designer",             description: "Web デザインレビュー", prompt: "..." })
```

### 3.2 簡易モード

```
Agent({ subagent_type: "implementation-engineer", description: "実装レビュー", prompt: "..." })
Agent({ subagent_type: "test-engineer",            description: "テストレビュー", prompt: "..." })
Agent({ subagent_type: "security-engineer",        description: "セキュリティレビュー", prompt: "..." })
```

---

## 4. プロンプト組み立てルール

各エージェント定義（`agents/{name}.md`）の末尾に「プロンプトテンプレート」セクションがある。
そのテンプレートに以下の値を差し込んで `prompt` パラメータに渡す。

### 4.1 共通変数

| 変数 | 値の作り方 |
|------|----------|
| `{{対象種別}}` | 「コード変更」「プルリクエスト」「ブランチ差分」 等 |
| `{{背景・要件の説明}}` | コミットメッセージ・PR 説明・ユーザーから受け取った文脈を要約 |
| `{{レビュー対象の詳細}}` | 変更ファイル一覧 + 主要差分のスニペット + 関連ファイルへのパス |

### 4.2 エージェント固有の追加変数

| エージェント | 追加変数 |
|------------|---------|
| `security-engineer` | `{{システムの概要・技術スタック・公開範囲}}` |
| `architect` | `{{システムの全体像・既存アーキテクチャ・技術スタック}}` |
| `dba` | `{{データベース種別・テーブル規模・想定データ量・アクセスパターン}}` |
| `test-runner` | 対象テストプロジェクトの場所・実行可能なテストクラス・想定実行時間 |
| `dependency-safety` | プロジェクトの依存定義ファイル差分（`*.csproj` / `package-lock.json` / `requirements.txt` 等）・対象アプリの公開範囲 |
| `web-designer` | UI 変更の対象画面・想定ターゲットブラウザ／デバイス・既存デザイン規約への参照 |

### 4.3 プロジェクト規約参照の指示（共通・必須）

各エージェントのプロンプトには、以下の規約参照指示を **必ず冒頭付近に含める**。

```text
## プロジェクト規約の確認（最優先）
レビュー対象リポジトリの以下を必ず確認し、存在する規約を最優先で評価基準とせよ。
- CLAUDE.md / .claude/CLAUDE.md
- .claude/rules/ 配下のルール
- CONTRIBUTING.md / docs/ 配下のスタイルガイド・設計ドキュメント
- .editorconfig / .eslintrc* / .prettierrc* / .stylelintrc* 等の整形・Linter 設定
規約が存在する場合はそれを引用して指摘の根拠に含めること。
存在しない場合のみ各エージェント定義の標準フレームワーク（OWASP / SOLID / WCAG 等）と言語別レビュー観点プロファイルにフォールバックする。
```

### 4.3.5 言語別レビュー観点プロファイルの参照指示（共通・必須 / O10）

各エージェントのプロンプトには、Step 2 の検出結果（`language-profiles` 引数）に基づく言語・FW 観点プロファイルの参照指示を含める。

```text
## 言語別レビュー観点
検出言語・FW: {{検出結果の一覧（主/副の区分付き）}}
以下のプロファイルを Read し、あなたの担当観点（各ファイル内の【担当】表記）を評価に使用せよ:
{{適用プロファイルのパス一覧（${CLAUDE_PLUGIN_ROOT}/references/languages/*.md / frameworks/*.md）}}
プロジェクト独自規約（適用規約サマリ）が最優先。プロファイルのデファクト規約はプロジェクト規約が無い項目のみに適用する。
観点プロファイルが無い言語は、汎用観点のみで評価しその旨を制約事項に明記する。
```

エージェント別の主担当プロファイルの対応は `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 を参照。

### 4.4 全エージェントに共通で末尾に付ける指示

```text
## レビュー範囲の制約
- test-runner 以外は静的レビューのみ。コード・スクリプト・テストは実行しない。
- 検出した指摘は **件数上限なく全件** 報告する。切り捨ては行わない。
- 同一指摘の重複を避け、最も適切な箇所に 1 件としてまとめる。
- 指摘なしの場合は 1 行で「指摘なし」と返答する。

## 別 PR / 別チケット推奨の禁止 + PR 外への影響禁止
- 指摘・改善提案・所見の本文に **「別 PR で対応してください」「別チケット化してください」「Issue を作成してください」** のような表現を入れてはならない。
- 本 PR の仕様・当初スコープから外れると判断した場合は、**「スコープ外」フラグ付き** で返却する（オーケストレーターが統合サマリの「スコープ外指摘」セクションにまとめる）。
- **PR 外のリソースへの書き込み禁止**: レビュー指摘の実行過程で Work Item / Issue / Boards カード / 別 PR / 別ブランチ / Wiki / 通知システム等への書き込み操作を行ってはならない（実行報告も含めない）。
- 観点別スキル・エージェントの `allowed-tools` に Work Item / Issue 作成系コマンド（`gh issue create` / `az boards work-item create` 等）を追加してはならない。
- 詳細は `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` セクション 1.5 を参照。

## 指摘ごとの必須項目
各指摘・改善提案・スコープ外指摘の必須項目は **`${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション 2** に従う（致命度 / 担当 / 箇所 / カテゴリ / 規約根拠 / 該当コード / 指摘内容 / 求める修正 / 理由・根拠 / スコープ判定 / **信頼度**）。提供できない項目は「該当なし」と明記する。

## 信頼度（Confidence）の付与（U15）
- 各指摘に **信頼度 0〜100** を付与する（`${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` セクション 7 の基準）
- コード上の事実として直接確認できる / 動的検証で実証済み = 90 以上
- 実行文脈への依存が残る = 70〜89、前提確認が望ましい = 60〜69
- 呼び出し元挙動・データ量等の **仮定に基づく指摘は 60 未満** とする（低信頼としてオーケストレーターが足切りする）

仕様判断が必要な場合のみ、論点・候補・推奨・確認先を記載（同 セクション2.1 の「仕様検討」項目を参照）。

## Finding ID は採番しない（オーケストレーター責務）
- エージェントは Finding ID（`CR-NNN`）を採番しない。採番は code-review Step 6 で一括実施される
- 詳細: `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション1.5
```

---

## 5. 結果の取り扱い

各エージェントから返ってきた結果は **要約してメインに取り込む**。

- 各エージェントの「総合評価」「指摘事項リスト」「推奨改善」を抽出
- `severity-ranking.md` の重複統合ルールに従って統合
- `output-format.md` のフォーマットに従ってサマリ生成
