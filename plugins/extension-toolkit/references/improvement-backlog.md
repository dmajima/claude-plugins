# Improvement Backlog（extension-toolkit）

別セッションで対応すべき extension-toolkit 自身の改善要求バックログ。プラグイン作成・改修ワークフローの品質向上に資する課題をここに集約する。

> **このファイルの位置付け**: 通常のスキル動作では参照されない（人間および別セッションの Claude が改修方針を立てる際のリファレンス）。対応完了時は該当エントリを `[DONE: <commit-sha>]` で marking し、一定期間後に削除する（履歴は git log に委ねる）。

---

## カテゴリ A: ワークフロー強化（プロセス改善）

### A-1. プラグイン・スキル作成/改修完了時の動作デモ + 承認フロー（必須化）

| 項目 | 内容 |
|-----|------|
| 課題 | 現状の `extension-reviewer` は静的解析・コードレビューに留まり、実機での動作検証を強制していない。実装バグ（例: PowerShell `TrimStart` の char 変換エラー）が静的解析を素通りしてリリース直前まで発見されないリスクがある |
| 対応 | プラグイン・スキル作成/改修の完了報告前に、**実機での動作デモ + ユーザー承認** を経るフェーズを追加する |
| 実装案 | `completion-checklist.md` に「ユーザー向け動作デモ実施・承認取得」を必須項目として追加。`*-toolkit` スキルの引き渡しフェーズで「デモ実施 → AskUserQuestion で承認確認」を組み込む |
| 関連 ADR | 新規 ADR（例: ADR-031「動作デモ承認フローの必須化」）として extension-toolkit/references/architecture-decisions.md に記録 |
| 優先度 | High |

### A-2. UI レビューの追加（ユーザー向け UI が存在する場合）

| 項目 | 内容 |
|-----|------|
| 課題 | `extension-reviewer` のエージェント構成（impl/sec/test/arch）に UI 観点が含まれない。AskUserQuestion による対話 UI / コンソール出力フォーマット / エラーメッセージ等の UX 品質が体系的にレビューされていない |
| 対応 | プラグイン・スキルにユーザー向け UI（AskUserQuestion / コンソール出力 / コマンド引数仕様 等）が含まれる場合、`extension-reviewer` のエージェント構成に **UX デザイナー観点** を必須として追加する |
| 実装案 | `references/review-perspectives.md` に「UI 含有プラグインは ux-designer エージェントを必須」と明記。`team-selection.md` に「UI レビュー観点」のチームメンバー追加 |
| 関連エージェント | `ux-designer`（既存テンプレート）|
| 優先度 | Medium |

### A-3. スコープ・作業単位の細かいコミット分割ルール

| 項目 | 内容 |
|-----|------|
| 課題 | 大規模な変更を 1 コミットにまとめると、レビュー困難・部分ロールバック困難・コミット履歴の理解負荷が高い。今回の `maintenance` プラグイン統合コミット（53 ファイル / +327/-625 行）は履歴上で 1 トランザクションだが、内容は「改名」「統合」「ADR 追加」「README 更新」「移行手順記載」と複数スコープを含む |
| 対応 | プラグイン・スキル作成/改修時のコミット分割ルールを明文化。**スコープ・作業単位ごとに独立コミット**を作成することを必須化 |
| 実装案 | `references/` に新規 `commit-granularity.md` を追加。例として「ディレクトリリネーム」「ファイル移管」「内容更新」「ADR 追加」「README/marketplace 同期」「移行手順記載」を別コミットとして分割する原則を記載 |
| 既存 git 慣習との整合 | Conventional Commits 互換、`feat:` / `fix:` / `refactor:` / `docs:` 等を活用 |
| 優先度 | Medium |

### A-4. コマンド引数の AskUserQuestion 強制化（単純 1 引数を除く）

| 項目 | 内容 |
|-----|------|
| 課題 | 複数の `--key value` ペアを CLI で同時指定する設計は、コマンドのスキャナビリティを下げ、ユーザがフラグ仕様を覚える負担を増やす。`/cleanup-config --set-days 60 --set-keep-recent 5 --set-scope global --set-active-minutes 10` のような呼び出しは推奨できない |
| 対応 | **コマンドでの引数指定は「単純な 1 引数」のみ許可**。それを超える情報収集は `AskUserQuestion` で対話的に行うことを必須化。「単純な 1 引数」とは `--dry-run` / `--show` / `<path>` 等の **単一フラグまたは単一値** を指す |
| 実装案 | `references/` に新規 `argument-policy.md` を追加。各コマンドの `argument-hint` を「単純な 1 引数」レベルに圧縮し、複数情報の収集は本文で対話モードに誘導する。後方互換性のため CLI 引数モードを残す場合は「上級者・自動化向け」と明示 |
| 例外 | 自動化スクリプト（CI / バッチ実行）向けに `--non-interactive` フラグでの一括指定は許容するが、これは非推奨パスとして本文末尾に隔離する |
| 関連 ADR | ADR-023（`argument-hint` 必須化）と整合。`argument-hint` の長さを「読みやすい範囲」に制約する補強 |
| 優先度 | High（UX 改善・新規コマンド設計時に直接影響）|

### A-5. ユーザ対話の AskUserQuestion 原則化

| 項目 | 内容 |
|-----|------|
| 課題 | ユーザとの選択的対話を「テキスト対話（Claude が質問→ユーザが応答）」で行うと、選択肢の明示性が下がる・推奨値が不明・選択漏れがある等の UX 問題が発生しやすい |
| 対応 | **ユーザとの対話は AskUserQuestion を原則として使用**。AskUserQuestion が利用できない / 推奨できない場合は、Claude がその旨をユーザに通知し、対話手段の選択を仰ぐ |
| 利用不可・非推奨ケース | (1) AskUserQuestion ツール自体が無効化されている環境、(2) 自由入力が主体で options 2-4 個の枠に収まらないケース（パスワード入力など）、(3) 入力値の生検証が必要なケース（複雑なバリデーション）|
| 実装案 | `references/` に新規 `user-interaction-policy.md` を追加（既存の `user-interaction.md` を拡張）。AskUserQuestion 利用可否の判断フローと、利用不可時のフォールバック手順を明記 |
| 関連 | A-4（引数の AskUserQuestion 強制化）と整合 |
| 優先度 | High |

### A-6. AskUserQuestion の発火戦略（分岐 = 複数回 / 非分岐 = 1 回複数質問）

| 項目 | 内容 |
|-----|------|
| 課題 | AskUserQuestion を分岐のある対話で 1 回に詰め込むと、後段の選択肢が前段の選択結果に依存できず、不適切な選択肢を提示してしまう。一方、分岐のない複数質問を 1 回ずつ発火すると対話往復が増えて UX が低下する |
| 対応 | **分岐の有無で発火戦略を使い分ける**。<br>(A) **質問が分岐する場合**: 段階的に複数回発火（前段の選択結果を読み取り、後段の options を構築）<br>(B) **分岐のない複数質問の場合**: 1 度の AskUserQuestion で `questions` 配列に並べて発火（往復を最小化）|
| 実装例 | `/cleanup-config`: 全 4 設定項目を 1 回で発火（非分岐）/ `/sync-map-delete`: Step 1（削除対象）→ Step 2（最終確認）の 2 段階発火（前段の選択で後段の発火可否が変わる、分岐型）|
| 実装案 | `references/` に新規 `askquestion-strategy.md` を追加（または `user-interaction-policy.md` の一節として記述）。判断フローチャート + 既存スキルからの実装例を列挙 |
| 関連 | A-5（AskUserQuestion 原則化）と整合 |
| 優先度 | High |

---

## カテゴリ B: 自動チェック強化（静的解析の限界補完）

### B-1. PowerShell 文字列 API シグネチャの自動チェック

| 項目 | 内容 |
|-----|------|
| 課題 | `extension-reviewer` の自動チェック（`run_checks.py`）は SKILL.md 行数・description 文字数・JSON valid 等を検証するが、**PowerShell スクリプトの API シグネチャ齟齬**（例: `String.TrimStart('./', '/')` の char 変換エラー）は検出できない |
| 発見契機 | 2026-05-18 のデモ実行で `sync-settings/sync.ps1` の Critical バグを発見（コミット `bbefbd0` で修正） |
| 対応 | PSScriptAnalyzer 等の PowerShell 静的解析ツールを `extension-reviewer` のチェックフローに統合する。`Invoke-ScriptAnalyzer` で文法・API 誤用を検出 |
| 実装案 | `references/scripts/checks/` に `run_psscriptanalyzer.ps1` を追加し、`.ps1` ファイルが含まれるプラグインで自動実行。検出ルールセットは `PSScriptAnalyzerSettings.psd1` で管理 |
| 課題依存 | PSScriptAnalyzer の自動インストール（venv の代替に PowerShell モジュールキャッシュを使う）|
| 優先度 | High |

### B-2. 実行ベース evals の CI 化（実機 dry-run 検証）

| 項目 | 内容 |
|-----|------|
| 課題 | 現状の `evals/` は動作分岐の **期待挙動例** を Markdown で記述するだけ。実機で dry-run を実行して期待出力と一致するかは人間レビューに委ねている |
| 発見契機 | 2026-05-18 のデモ実行で初めて Critical バグを発見。レビューフェーズでは検出できず、デモ実施が事実上の最初の実行検証だった |
| 対応 | `evals/case-*.md` から「実行コマンド」と「期待出力の正規表現」を抽出し、CI で自動実行・比較する仕組みを追加。dry-run モード前提なので副作用なし |
| 実装案 | `case-*.md` のフロントマターに `runnable: true` フラグと `command:` フィールド + `expect_output_regex:` を追加。`references/scripts/evals/run_evals.py` で並列実行・diff 検証 |
| 適用範囲 | dry-run 系（破壊的でない）evals のみ自動実行。実削除・実適用系はオプトイン |
| 優先度 | High |

### B-3. デモ実行スクリプトのテンプレート化

| 項目 | 内容 |
|-----|------|
| 課題 | プラグイン・スキル完了時のデモ実施には毎回 ad-hoc に PowerShell コマンドを組み立てている。再現性・標準化が不足 |
| 対応 | スキル作成時に `evals/demo.ps1` 等のデモ実行スクリプトを必須生成。`AskUserQuestion` 連動の対話シナリオもテンプレート化 |
| 実装案 | `skill-toolkit` の生成テンプレートに `evals/demo.ps1` を含める。スキルの代表的な dry-run + 主要分岐の自動デモを実装 |
| 優先度 | Medium |

---

## カテゴリ C: ドキュメント・命名（軽微）

### C-1. PowerShell 文字列 API の落とし穴を SSOT 化

| 項目 | 内容 |
|-----|------|
| 課題 | `TrimStart(string)` ではなく `TrimStart(char[])` の仕様等、PowerShell（.NET）の API 落とし穴がプラグイン開発時に繰り返し発生し得る |
| 対応 | `references/` に `powershell-pitfalls.md` を追加。発見した落とし穴を蓄積していく SSOT として運用 |
| 初期エントリ | (1) `String.TrimStart` の char[] 引数仕様、(2) `Get-ChildItem` の `LinkType` 値（null/SymbolicLink/Junction/HardLink）、(3) `Resolve-Path` の相対パス挙動、(4) `Get-FileHash` のディレクトリ動作 |
| 優先度 | Low（蓄積型） |

---

## 対応優先順位（推奨）

| 優先度 | エントリ | 理由 |
|-------|---------|------|
| **High** | A-1, A-4, A-5, A-6, B-1, B-2 | バグ流出防止 + UX 大幅改善。発見契機が今回のセッションで、再発防止 + 一貫性確保が急務 |
| Medium | A-2, A-3, B-3 | プロセス・ワークフロー改善。リリース品質に長期的に効く |
| Low | C-1 | 蓄積型ドキュメント。気づいたタイミングで追記 |

---

## 完了マーキング規則

対応完了時、該当エントリの先頭に `[DONE: <commit-sha> <YYYY-MM-DD>]` を追加する。

```markdown
### [DONE: abc1234 2026-06-01] A-1. プラグイン・スキル作成/改修完了時の動作デモ + 承認フロー（必須化）
```

`[DONE: ...]` 付きのエントリは次回更新時に削除し、git log で履歴を辿れるようにする（リポジトリ内ドキュメントの更新履歴記載禁止ルール `conventions.md` 節 12.5 に準拠）。
