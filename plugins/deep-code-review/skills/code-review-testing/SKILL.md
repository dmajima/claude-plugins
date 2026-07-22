---
name: code-review-testing
description: deep-code-review の観点別スキル。コード変更をテスト観点（テスト品質・ユニット実行）でレビュー。「テストコードをレビューして」「テスト網羅性を確認」「ユニットテストを実行」「エッジケース/モック過剰を確認」や code-review の委譲で起動する。Use when reviewing unit-test quality or running unit tests. SKIP when reviewing implementation/security/architecture/frontend (use the matching code-review-* skill).
allowed-tools:
  - Read
  - Grep
  - Glob
  - Agent(test-engineer)
  - Agent(test-runner)
  - Bash(git *)
  # 動的検証用（リポジトリ側で必要に応じて追加）:
  # - Bash(dotnet *)   # dotnet test
  # - Bash(npm *) / Bash(jest *) / Bash(vitest *) / Bash(pytest *)
  # - Bash(pwsh *)
---

# code-review-testing スキル

## 責務

コード変更を **テスト観点** からレビューする。観点は2つ:

## トリガー条件

- code-review オーケストレーターから Skill ツール経由で委譲された場合（標準・簡易モード両方の必須スキル）
- 「テストコードをレビューして」「テスト網羅性を確認して」「ユニットテストを実行して」と言われた場合

## 前提

- レビュー対象の差分・プロジェクト規約サマリが引数で渡されていること
- test-engineer / test-runner エージェント定義が `${CLAUDE_PLUGIN_ROOT}/agents/` に存在すること

| 観点 | 担当エージェント | 責務 |
|------|----------------|------|
| テストコード品質 | test-engineer | ユニットテストの網羅性・エッジケース・モック過剰・命名・AAA パターン遵守 |
| ユニットテスト実行 | test-runner | プロジェクトのユニットテスト実行・pass/fail 報告（**実行コマンド可**） |

## 動的検証

`test-runner` は対応 Bash 権限が許可された場合のみ実コマンドを実行。
追加すべき権限例: `Bash(dotnet *)` / `Bash(npm *)` / `Bash(jest *)` / `Bash(vitest *)` / `Bash(pytest *)` / `Bash(pwsh *)` 等。
権限なし・テスト基盤なし・実行不能の場合は SKIPPED として記録。

## E2E・結合テストはスコープ外

`test-runner` が実行するのは **ユニットテストのみ**。E2E / 結合 / ブラウザテスト / 性能テストは本スキルの対象外。

## 実行モード判定

**起動形態（委譲 / 単独）** を判定する。対話 / 非対話の UI モード判定（`AskUserQuestion`）はオーケストレーター（`code-review`）責務であり本スキルは行わない。

| 入力 | 起動形態 | 動作 |
|-----|---------|------|
| `code-review` から Skill 委譲（引数に規約サマリ / `language-profiles` 等） | 委譲 | モード・スコープ・言語プロファイルは確定済みとして受領し、非対話で観点別レビューを実行。結果は中間レポート（内部データ）として返す |
| ユーザーが直接起動（「テストコードをレビューして」等） | 単独 | 対象差分・言語/FW を自己検出（O10）し、`progress.md` を自スキルで作成（O8）。標準/簡易モードの確認は行わない |

## 入力

| 引数 | 内容 |
|------|------|
| スコープ | レビュー対象（差分・PR・ファイル一覧） |
| プロジェクト規約サマリ | `CLAUDE.md` / `.claude/rules/` 等の要約 |
| 言語プロファイル | `language-profiles=<...>` 形式。検出言語・FW の観点プロファイルパス一覧（`${CLAUDE_PLUGIN_ROOT}/references/languages/` / `frameworks/`）。未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10） |
| テストプロジェクト情報 | 対象テストプロジェクトの場所・実行コマンド・想定実行時間（任意） |

## 実行フロー

1. 引数を解釈し、テストファイル差分・関連プロダクトコード・テストプロジェクトを確定
1.5. `language-profiles` の適用観点プロファイルを確認し（未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出）、各エージェントのプロンプトに言語プロファイル参照指示（`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 のテンプレート）を含める。**言語プロファイルは hub（`<言語>.md`）＋観点別 details（`-impl` / `-core` / `-security`）の 2 層構成**であり、各エージェントは hub と **自担当節に対応する details のみ** を Read する（test-engineer / test-runner は主に hub 節6 の動的検証コマンド）（O10）
2. 2エージェントを **1メッセージ内で並列起動**:
   ```
   Agent({ subagent_type: "test-engineer", ... })
   Agent({ subagent_type: "test-runner",   ... })
   ```
3. 各エージェントの結果を **観点別中間レポート** にまとめて返却

## 参照

共通リファレンスは **`${CLAUDE_PLUGIN_ROOT}/references/common-references.md`** に集約済み（プラグイン内 SSOT）。
ルール ID 体系（Universal U1〜U16 + Observation O1〜O10）は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

## 達成チェックリスト

- `${CLAUDE_SKILL_DIR}/references/checklist.md` — 中間レポート返却前のルール達成チェック

> 統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）責務。本スキルは中間レポート（後述「出力フォーマット」の形式）を返すのみ。

## 出力フォーマット

```markdown
## テスト観点レビュー結果

### test-engineer
- 検出したテスト品質問題: ...
- 推奨される追加テストケース: ...

### test-runner
- 実行ステータス: GREEN | RED | SKIPPED（理由）
- 実行コマンド: ...
- 失敗したテスト（RED時）: ファイル:メソッド・失敗理由
```

## 重要な制約

- Write ツールによるレビュー対象ソースコードの変更は行わない

## 責務外

進捗管理（U5・複数エージェント並列起動時の `progress.md` 維持）と、自スキル外と判断した指摘の他観点別スキルへの振分けルールは **`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション4 / セクション5** に集約済み。
