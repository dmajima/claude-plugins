---
name: command-toolkit
description: Claude Code のスラッシュコマンド（commands/{name}.md）を新規作成・改修するスキル。「新しい /foo コマンドを作って」「foo コマンドを更新」「○○用のコマンドが欲しい」等で起動する。Use when creating or modifying a slash command file. SKIP when target is a skill (skill-toolkit), agent (agent-toolkit), hook (hook-toolkit), plugin shell (plugin-toolkit), MIT LICENSE setup (mit-license-toolkit), or review (extension-reviewer).
---

# Command Toolkit

Claude Code のスラッシュコマンドファイル（`{plugin}/commands/{name}.md` または `<repo>/.claude/commands/{name}.md`）を作成・改修するスキル。プラグイン横断テンプレート（`${CLAUDE_PLUGIN_ROOT}/references/templates/command/command.md`）に従って構造化された生成物を出力する。

## 責務

- 新規スラッシュコマンドファイルの生成
- 既存コマンドの改修（プロンプト追加・分岐追加）
- 命名衝突チェック
- frontmatter `description` の整合確認

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| スキル本体の生成 | `skill-toolkit` |
| プラグイン外形の生成 | `plugin-toolkit` |
| エージェント・チームの生成 | `agent-toolkit` |
| フック設定の生成 | `hook-toolkit` |
| README 生成・更新 | `readme-toolkit` |
| マーケットプレイス公開 | `marketplace-publisher` |
| 完成後のレビュー | `extension-reviewer` |

## トリガー条件

- 「新しい `/{name}` コマンドを作って」「`{name}` コマンドを作成」
- 「`{name}` コマンドを更新」「`{name}` に {機能} を追加」
- 「○○用のコマンドが欲しい」

このスキルを起動しないケース:

- 「スキルを作って」（→ `skill-toolkit`）
- 「プラグインを作って」（→ `plugin-toolkit`）

## 前提

- コマンド名（kebab-case、`/` 抜き）
- 配置先（`<repo>/.claude/commands/` or `plugins/{plugin}/commands/`）
- コマンドの効果（1 行説明）
- 引数の有無と意味

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり、または引数で全パラメータ指定 | 非対話 | デフォルト値・引数値で確定し進行 |
| 上記以外 | 対話 | 不足パラメータをユーザに確認 |

## 実行フロー

### 1. シナリオ判定

| 条件 | シナリオ |
|-----|---------|
| コマンドファイルが既存 | 既存改修 |
| 未存在 | 新規作成 |

### 2. パラメータ確定

| パラメータ | 必須 | 例 |
|----------|------|---|
| コマンド名（kebab-case） | 必須 | `extension` |
| 1 行説明（60 文字以内） | 必須 | `拡張要素の作成・公開を支援` |
| 配置先 | 必須 | スタンドアロン or `plugins/{plugin}/` |
| 引数仕様 | 任意 | 引数のパターン |
| ルーティング先（オーケストレータの場合） | 任意 | スキル名 or 他コマンド名 |

### 3. 命名衝突チェック

配置先に同名 `.md` がある場合はユーザに上書き可否を確認。

### 4. テンプレート展開

`${CLAUDE_PLUGIN_ROOT}/references/templates/command/command.md` を配置先にコピーし、プレースホルダ置換。詳細は [references/procedures.md](references/procedures.md) を参照。

### 5. プロンプト本体の充填

ユーザ要件に応じて以下を本文に追加:

| 要素 | 配置 |
|-----|------|
| 動作モード判定（対話/非対話） | テンプレート既定 |
| ルーティング表 | テンプレート既定 |
| 引数が空の場合の確認項目 | テンプレート既定 |
| 共通の終了処理 | テンプレート既定 |
| コマンド固有のロジック | 本文末尾 |

### 6. description の検証

[`../../references/guides/description-guide.md`](../../references/guides/description-guide.md) のコマンド向けルールに準拠:

- 60 文字以内
- 体言止め可
- コマンドの効果 1 つ
- 引数仕様は `argument-hint` に書く（description には書かない）

### 6.5. argument-hint の必須化（ADR-023）

引数を受け取るコマンド（本文に `$ARGUMENTS` を含む / ルーティング表を持つ）は frontmatter に `argument-hint` を **必ず記載** する。表記規則は [`../../references/guides/description-guide.md`](../../references/guides/description-guide.md) 節 4.1 を参照。

| 区分 | 表記 |
|------|------|
| 必須引数 | `<引数名>` |
| 省略可引数 | `[引数名]` |
| フラグ（値あり） | `[--flag 値]` |
| フラグ（値なし） | `[--flag]` |

引数を一切受け取らないコマンド（`$ARGUMENTS` 不参照）は `argument-hint` を省略してよい。

### 7. 検証

- [ ] frontmatter `description` あり、60 文字以内
- [ ] frontmatter `argument-hint` あり（引数受取コマンドの場合）
- [ ] `argument-hint` 60 文字以内・改行なし・表記規則順守
- [ ] プレースホルダ `{...}` 残存なし
- [ ] パスポータビリティ合格
- [ ] 配置先パスが正しい

### 8. 引き渡し

**作業完了報告の前に必須**: [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) 節 2.4 に従い、ユーザ向け動作デモ（コマンド起動・引数分岐・AskUserQuestion 実発火）を実施し、`AskUserQuestion` で承認を取得する（ADR-032）。

- 生成ファイルパスを提示
- プラグイン内配置の場合は `marketplace-publisher` への接続を提案
- README 更新が必要な場合は `readme-toolkit` への接続を提案

## 重要な制約

- description 60 文字以内（人間向け UI 表示）
- 引数仕様の description 記載禁止（本文に書く）
- 既存ファイル更新時のエンコーディング維持
- パスポータビリティチェック必須
- 利用者環境非依存性の維持（[`../../references/policies/self-containment.md`](../../references/policies/self-containment.md)、ADR-022）
- 第三者レビュー起動時はフレッシュ Agent インスタンスで起動（[`../../references/checklists/review-freshness.md`](../../references/checklists/review-freshness.md)、ADR-021）
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/guides/user-interaction.md`](../../references/guides/user-interaction.md) + [`../../references/guides/askquestion-strategy.md`](../../references/guides/askquestion-strategy.md)）
- コマンド引数仕様は [`../../references/policies/argument-policy.md`](../../references/policies/argument-policy.md) の「単純な 1 引数」原則に従う
- 作業完了報告前に [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/policies/conventions-structure.md`](../../references/policies/conventions-structure.md) |
| description 設計 | [`../../references/guides/description-guide.md`](../../references/guides/description-guide.md) |
| ポータブルパス | [`../../references/policies/path-portability.md`](../../references/policies/path-portability.md) |
| 検証ルール | [`../../references/checklists/validation-rules.md`](../../references/checklists/validation-rules.md)（節 1 + 2.3） |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| 動作例 | [`evals/`](evals/) |
