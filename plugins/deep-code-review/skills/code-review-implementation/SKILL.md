---
name: code-review-implementation
description: |
  実装品質観点（コード正確性・コーディング規約・パフォーマンス）でコード変更をレビューする観点別スキル。
  内部で implementation-engineer / linter-static-analysis / performance-reviewer の3エージェントを並列起動する。

  以下の場面で使用する:
  - 「実装品質をレビューして」「コードの正確性を確認して」と言われた場合
  - 「Linter / 静的解析だけ実行して」と言われた場合
  - 「パフォーマンスをレビューして」「N+1 / ブロッキング / メモリを見て」と言われた場合
  - code-review オーケストレーターから委譲された場合（標準・簡易モード両方の必須スキル）
allowed-tools:
  - Read
  - Grep
  - Glob
  - Agent(implementation-engineer)
  - Agent(linter-static-analysis)
  - Agent(performance-reviewer)
  - Bash(git *)
  # 動的検証用（リポジトリ側で必要に応じて追加）:
  # - Bash(dotnet *)   # ビルド・Linter
  # - Bash(npm *)
  # - Bash(eslint *) / Bash(prettier *) / Bash(tsc *)
  # - Bash(pwsh *)
---

# code-review-implementation スキル

## 責務

コード変更を **実装品質観点** からレビューする。観点は3つに分解:

## トリガー条件

- code-review オーケストレーターから Skill ツール経由で委譲された場合（標準・簡易モード両方の必須スキル）
- 「実装品質をレビューして」「コードの正確性を確認して」「Linter / 静的解析だけ実行して」と言われた場合

## 前提

- レビュー対象の差分・プロジェクト規約サマリが引数で渡されていること
- implementation-engineer / linter-static-analysis / performance-reviewer エージェント定義が `${CLAUDE_PLUGIN_ROOT}/agents/` に存在すること

| 観点 | 担当エージェント | 責務 |
|------|----------------|------|
| 実装正確性 | implementation-engineer | ロジックの正しさ・例外処理・契約整合性・Quality/Style・Simplification |
| コーディング規約・整形 | linter-static-analysis | プロジェクト規約・整形・型違反の検出（**ビルド/Linter コマンド実行可**） |
| パフォーマンス | performance-reviewer | N+1・ブロッキング・メモリ・状態管理機構肥大化 |

## 動的検証

`linter-static-analysis` は対応する Bash 権限が許可されている場合のみ実コマンドを実行する。
追加すべき権限例: `Bash(dotnet *)` / `Bash(npm *)` / `Bash(eslint *)` / `Bash(prettier *)` / `Bash(tsc *)` / `Bash(pwsh *)` / `Bash(ruff *)` 等。
権限がない場合は SKIPPED として記録（「未実施」を「問題なし」と書かない）。

## 実行モード判定

観点別スキルは **起動形態（委譲 / 単独）** を判定する。対話 / 非対話の UI モード判定（`AskUserQuestion`）はオーケストレーター（`code-review`）の責務であり、本スキルは行わない。

| 入力 | 起動形態 | 動作 |
|-----|---------|------|
| `code-review` から Skill 委譲（引数に規約サマリ / `language-profiles` 等） | 委譲 | モード・スコープ・言語プロファイルは確定済みとして受領し、非対話で観点別レビューを実行。結果は中間レポート（内部データ）として返す |
| ユーザーが直接起動（「実装品質をレビューして」等） | 単独 | 対象差分・言語/FW を自己検出（O10）し、`progress.md` を自スキルで作成（O8）。標準/簡易モードの確認は行わない |

## 入力（呼び出し時の引数）

オーケストレーターまたはユーザーから以下を受け取る:

| 引数 | 内容 |
|------|------|
| スコープ | レビュー対象（差分・PR・ファイル一覧） |
| プロジェクト規約サマリ | `CLAUDE.md` / `.claude/rules/` / `.editorconfig` 等の要約 |
| 言語プロファイル | `language-profiles=<...>` 形式。検出言語・FW の観点プロファイルパス一覧（`${CLAUDE_PLUGIN_ROOT}/references/languages/` / `frameworks/`）。未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10） |
| 変更分類 | 機能追加 / バグ修正 / リファクタリング / 設定変更 等 |
| 仕様書サマリ（任意） | `spec_summary=<要約>` 形式。指定がある場合は implementation-engineer が **仕様整合性** を追加観点として評価する |

## 仕様整合性チェック（仕様書指定時のみ）

`spec_summary` が指定された場合、implementation-engineer は通常の実装品質観点に加えて以下を評価する:

| 観点 | 検出内容 |
|------|---------|
| 実装漏れ | 仕様書記載があるが実装されていない機能・パラメータ・エラーケース |
| 仕様逸脱 | 仕様書と異なる挙動・命名・I/F |
| 仕様矛盾 | 実装と仕様書の根本的な乖離 |

仕様書未指定時はこの観点をスキップし、規約観点のみで評価する。

## 実行フロー

1. 引数を解釈し、レビュー対象差分・関連ファイル・規約を確定する
1.5. `language-profiles` の適用観点プロファイルを確認し（未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出）、各エージェントのプロンプトに言語プロファイル参照指示（`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 のテンプレート）を含める（O10）
2. 3エージェントを **1メッセージ内で並列起動**:
   ```
   Agent({ subagent_type: "implementation-engineer", ... })
   Agent({ subagent_type: "linter-static-analysis",   ... })
   Agent({ subagent_type: "performance-reviewer",     ... })
   ```
3. 各エージェントの結果を **観点別中間レポート** にまとめて返却
4. 重複指摘は最も重い重要度を採用し、指摘ごとに必須項目（致命度・指摘箇所・指摘内容・求める修正・理由・根拠）を漏れなく含める

## 参照

本観点別スキルが参照する共通リファレンスは **`${CLAUDE_PLUGIN_ROOT}/references/common-references.md`** に集約済み（プラグイン内 SSOT）。
ルール ID 体系（Universal U1〜U16 + Observation O1〜O10）は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

## 達成チェックリスト

- `${CLAUDE_SKILL_DIR}/references/checklist.md` — 中間レポート返却前のルール達成チェック

> 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。本スキルは中間レポート（後述「出力フォーマット」セクションの形式）を返すのみ。

## 出力フォーマット

中間レポートは以下の構造で返却する:

```markdown
## 実装品質観点レビュー結果

### implementation-engineer
- Critical: ...
- High: ...
- Medium: ...
- Low / Suggestions: ...

### linter-static-analysis
- 動的検証: EXECUTED | SKIPPED（理由）
- 検出した違反: ...

### performance-reviewer
- 検出した性能問題: ...
- 計測データ（あれば）: ...
```

オーケストレーター（`code-review`）はこの中間レポートを他観点別スキルの結果と統合して最終サマリを生成する。

## 重要な制約

- Write ツールによるレビュー対象ソースコードの変更は行わない
- 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務であり、本スキルは中間レポートを返すのみ

## 責務外

進捗管理（U5・複数エージェント並列起動時の `progress.md` 維持）と、自スキル外と判断した指摘の他観点別スキルへの振分けルールは、**`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション4 / セクション5** に集約済み（共通化済み）。
