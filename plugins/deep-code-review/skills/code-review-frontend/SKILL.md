---
name: code-review-frontend
description: |
  フロントエンド観点（HTML / CSS / JavaScript / React / Vue / テンプレートエンジン・アクセシビリティ・レスポンシブ）で
  コード変更をレビューする観点別スキル。内部で web-designer エージェントを起動する。

  以下の場面で使用する:
  - 「フロントエンドをレビューして」「HTML / CSS / React / Vue / JS の変更を見て」と言われた場合
  - 「アクセシビリティを確認して」「レスポンシブ対応をレビューして」と言われた場合
  - UI / 画面 / フォームの変更時
  - code-review オーケストレーターから委譲された場合（標準モードのみ・UI 変更あり時）
allowed-tools:
  - Read
  - Grep
  - Glob
  - Agent(web-designer)
  - Bash(git *)
---

# code-review-frontend スキル

## 責務

コード変更を **フロントエンド・UI/UX 観点** からレビューする。

## トリガー条件

- code-review オーケストレーターから Skill ツール経由で委譲された場合（標準モード・UI 変更あり時）
- 「フロントエンドをレビューして」「HTML / CSS / Vue / JS の変更を見て」「アクセシビリティを確認して」と言われた場合

## 前提

- レビュー対象の差分・プロジェクト規約サマリが引数で渡されていること
- web-designer エージェント定義が `${CLAUDE_PLUGIN_ROOT}/agents/` に存在すること

| 観点 | 担当エージェント | 責務 |
|------|----------------|------|
| Web デザイン | web-designer | HTML 構造・CSS 設計・React / Vue コンポーネント・テンプレートエンジン（Razor / Liquid / Blade / Twig / Jinja2 等）・JS 動作・アクセシビリティ（WCAG）・レスポンシブ |

## 動的に省略可（責務はオーケストレーター）

> **注意**: 本スキルが呼ばれたら **必ずレビューを実行する**。スキル自体を呼ぶか否かの判断は **`code-review` オーケストレーター側** で行う。

オーケストレーター側で本スキル自体を省略する条件:
- HTML / テンプレート（`.cshtml` / `.razor` / `.blade.php` / `.vue` / `.jsx` / `.tsx` / `.liquid` / `.twig` 等） / CSS / 静的アセット / JavaScript の変更が一切ない場合

## 実行モード判定

観点別スキルは **起動形態（委譲 / 単独）** を判定する。対話 / 非対話の UI モード判定（`AskUserQuestion`）はオーケストレーター（`code-review`）の責務であり、本スキルは行わない。

| 入力 | 起動形態 | 動作 |
|-----|---------|------|
| `code-review` から Skill 委譲（引数に規約サマリ / `language-profiles` 等） | 委譲 | モード・スコープ・言語プロファイルは確定済みとして受領し、非対話で観点別レビューを実行。結果は中間レポート（内部データ）として返す |
| ユーザーが直接起動（「フロントエンドをレビューして」等） | 単独 | 対象差分・言語/FW を自己検出（O10）し、`progress.md` を自スキルで作成（O8）。標準/簡易モードの確認は行わない |

## 入力

| 引数 | 内容 |
|------|------|
| スコープ | レビュー対象（差分・PR・ファイル一覧） |
| プロジェクト規約サマリ | `CLAUDE.md` / `.claude/rules/` / `.stylelintrc*` / `.eslintrc*` / 既存デザインシステムドキュメント |
| 言語プロファイル | `language-profiles=<...>` 形式。検出言語・FW の観点プロファイルパス一覧（`${CLAUDE_PLUGIN_ROOT}/references/languages/` / `frameworks/`）。未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10） |
| 対象画面・想定ターゲット | UI 変更の対象画面・想定ターゲットブラウザ・デバイス |
| 既存デザイン規約への参照 | 既存コンポーネント命名・トークン・スペーシングルール（任意） |

## 実行フロー

1. 引数を解釈し、対象差分・関連テンプレート・スタイルファイル・JS を確定
1.5. `language-profiles` の適用観点プロファイルを確認し（未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出）、各エージェントのプロンプトに言語プロファイル参照指示（`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 のテンプレート）を含める（O10）
2. エージェントを起動:
   ```
   Agent({ subagent_type: "web-designer", ... })
   ```
3. 結果を **観点別中間レポート** にまとめて返却

## 参照

本観点別スキルが参照する共通リファレンスは **`${CLAUDE_PLUGIN_ROOT}/references/common-references.md`** に集約済み（プラグイン内 SSOT）。
ルール ID 体系（Universal U1〜U16 + Observation O1〜O10）は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

## 達成チェックリスト

- `${CLAUDE_SKILL_DIR}/references/checklist.md` — 中間レポート返却前のルール達成チェック

> 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。本スキルは中間レポート（後述「出力フォーマット」セクションの形式）を返すのみ。

## 出力フォーマット

```markdown
## フロントエンド観点レビュー結果

### web-designer
- HTML 構造・セマンティクスの問題: ...
- CSS 設計・命名・スタイル衝突: ...
- アクセシビリティ（WCAG）違反: ...
- レスポンシブ対応の問題: ...
- React / Vue / テンプレートエンジン / JS の問題: ...
```

## 重要な制約

- Write ツールによるレビュー対象ソースコードの変更は行わない
- 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務であり、本スキルは中間レポートを返すのみ

## 責務外

進捗管理（U5・複数エージェント並列起動時の `progress.md` 維持）と、自スキル外と判断した指摘の他観点別スキルへの振分けルールは、**`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション4 / セクション5** に集約済み（共通化済み）。
