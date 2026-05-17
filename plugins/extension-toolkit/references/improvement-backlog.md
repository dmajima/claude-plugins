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
| **High** | A-1, B-1, B-2 | バグ流出防止に直結。発見契機が今回のデモであり、再発防止が急務 |
| Medium | A-2, A-3, B-3 | プロセス・ワークフロー改善。リリース品質に長期的に効く |
| Low | C-1 | 蓄積型ドキュメント。気づいたタイミングで追記 |

---

## 完了マーキング規則

対応完了時、該当エントリの先頭に `[DONE: <commit-sha> <YYYY-MM-DD>]` を追加する。

```markdown
### [DONE: abc1234 2026-06-01] A-1. プラグイン・スキル作成/改修完了時の動作デモ + 承認フロー（必須化）
```

`[DONE: ...]` 付きのエントリは次回更新時に削除し、git log で履歴を辿れるようにする（リポジトリ内ドキュメントの更新履歴記載禁止ルール `conventions.md` 節 12.5 に準拠）。
