---
name: code-review-security
description: |
  セキュリティ観点（脅威モデル・OWASP/STRIDE・依存安全性）でコード変更をレビューする観点別スキル。
  内部で security-engineer / dependency-safety の2エージェントを並列起動する。

  以下の場面で使用する:
  - 「セキュリティをレビューして」「OWASP / STRIDE で確認して」と言われた場合
  - 「依存関係の脆弱性を見て」「破壊的変更の影響を確認して」と言われた場合
  - 認証・認可・データ保護・外部公開機能の変更時
  - code-review オーケストレーターから委譲された場合（標準・簡易モード両方の必須スキル）
allowed-tools:
  - Read
  - Grep
  - Glob
  - Agent(security-engineer)
  - Agent(dependency-safety)
  - Bash(git *)
  # 動的検証用（リポジトリ側で必要に応じて追加）:
  # - Bash(dotnet *)                                # dotnet list package --vulnerable
  # - Bash(npm *) / Bash(pnpm *) / Bash(yarn *)     # npm audit
  # - Bash(pip-audit *) / Bash(safety *) / Bash(govulncheck *)
  # - Bash(osv-scanner *) / Bash(trivy *)
  # - Bash(pwsh *)
---

# code-review-security スキル

## 責務

コード変更を **セキュリティ観点** からレビューする。観点は2つ:

## トリガー条件

- code-review オーケストレーターから Skill ツール経由で委譲された場合（標準・簡易モード両方の必須スキル）
- 「セキュリティをレビューして」「OWASP / STRIDE で確認して」「依存関係の脆弱性を見て」と言われた場合

## 前提

- レビュー対象の差分・プロジェクト規約サマリが引数で渡されていること
- security-engineer / dependency-safety エージェント定義が `${CLAUDE_PLUGIN_ROOT}/agents/` に存在すること

| 観点 | 担当エージェント | 責務 |
|------|----------------|------|
| セキュリティ（OWASP/STRIDE） | security-engineer | 脅威モデリング・脆弱性評価・攻撃面分析・認証/認可・入力検証・XSS/SQLi/CSRF 等 |
| 依存・デプロイ安全性 | dependency-safety | 依存関係・破壊的変更・マイグレーション・設定階層整合・**脆弱性スキャン実行可** |

## 動的検証

`dependency-safety` は対応する Bash 権限が許可されている場合のみ脆弱性スキャンを実コマンドで実行する。
追加すべき権限例: `Bash(dotnet *)` (dotnet list package --vulnerable) / `Bash(npm *)` (npm audit) / `Bash(pip-audit *)` / `Bash(osv-scanner *)` / `Bash(trivy *)` 等。
権限がない場合は SKIPPED として記録する。

## 実行モード判定

観点別スキルは **起動形態（委譲 / 単独）** を判定する。対話 / 非対話の UI モード判定（`AskUserQuestion`）はオーケストレーター（`code-review`）の責務であり、本スキルは行わない。

| 入力 | 起動形態 | 動作 |
|-----|---------|------|
| `code-review` から Skill 委譲（引数に規約サマリ / `language-profiles` 等） | 委譲 | モード・スコープ・言語プロファイルは確定済みとして受領し、非対話で観点別レビューを実行。結果は中間レポート（内部データ）として返す |
| ユーザーが直接起動（「セキュリティをレビューして」等） | 単独 | 対象差分・言語/FW を自己検出（O10）し、`progress.md` を自スキルで作成（O8）。標準/簡易モードの確認は行わない |

## 入力

| 引数 | 内容 |
|------|------|
| スコープ | レビュー対象（差分・PR・ファイル一覧） |
| プロジェクト規約サマリ | `CLAUDE.md` / `.claude/rules/` 等の要約 |
| 言語プロファイル | `language-profiles=<...>` 形式。検出言語・FW の観点プロファイルパス一覧（`${CLAUDE_PLUGIN_ROOT}/references/languages/` / `frameworks/`）。未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10） |
| 技術スタック・公開範囲 | 対象アプリの言語・フレームワーク・公開範囲（社内/インターネット）・取り扱う個人情報の有無 |
| 依存定義ファイル差分 | `*.csproj` / `package-lock.json` / `requirements.txt` 等の差分 |

## 実行フロー

1. 引数を解釈し、対象差分・依存定義ファイル・技術スタックを確定
1.5. `language-profiles` の適用観点プロファイルを確認し（未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出）、各エージェントのプロンプトに言語プロファイル参照指示（`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 のテンプレート）を含める（O10）
2. 2エージェントを **1メッセージ内で並列起動**:
   ```
   Agent({ subagent_type: "security-engineer",  ... })
   Agent({ subagent_type: "dependency-safety", ... })
   ```
3. 各エージェントの結果を **観点別中間レポート** にまとめて返却

## 参照

本観点別スキルが参照する共通リファレンスは **`${CLAUDE_PLUGIN_ROOT}/references/common-references.md`** に集約済み（プラグイン内 SSOT）。
ルール ID 体系（Universal U1〜U16 + Observation O1〜O10）は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

## 達成チェックリスト

- `${CLAUDE_SKILL_DIR}/references/checklist.md` — 中間レポート返却前のルール達成チェック

> 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。本スキルは中間レポート（後述「出力フォーマット」セクションの形式）を返すのみ。

## 出力フォーマット

```markdown
## セキュリティ観点レビュー結果

### security-engineer
- 検出した脅威・脆弱性（OWASP/STRIDE 分類）: ...
- 認証・認可・データ保護に関する指摘: ...

### dependency-safety
- 動的検証: EXECUTED | SKIPPED（理由）
- 検出した CVE / 既知脆弱性: ...
- 破壊的変更・マイグレーションリスク: ...
```

## 重要な制約

- Write ツールによるレビュー対象ソースコードの変更は行わない
- 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務であり、本スキルは中間レポートを返すのみ

## 責務外

進捗管理（U5・複数エージェント並列起動時の `progress.md` 維持）と、自スキル外と判断した指摘の他観点別スキルへの振分けルールは、**`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション4 / セクション5** に集約済み（共通化済み）。
