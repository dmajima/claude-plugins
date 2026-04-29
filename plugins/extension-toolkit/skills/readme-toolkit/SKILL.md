---
name: readme-toolkit
description: Claude Code のプラグイン・スキル等の README.md（人間向けリファレンス）を新規作成・更新するスキル。「foo プラグインの README を書いて」「bar スキルの README を更新」「README を最新化」などの依頼で起動する。Use when the user wants to create or update a human-facing README.md for a plugin, skill, or other artifact. SKIP when the user wants to create a SKILL.md (use skill-toolkit), plugin.json (use plugin-toolkit), or other body files.
---

# README Creator

Claude Code のプラグイン・スキル等の `README.md`（人間向けリファレンス）を作成・更新するスキル。プラグイン横断テンプレート（`templates/readme/README.md`）を使用する。

## 責務

- プラグインの `README.md` 生成・更新
- スキルの `README.md` 生成・更新
- 提供機能・利用方法・ファイル構成・依存システムの記述
- **常に最新版のみを反映**（過去履歴・変更経緯の記載は禁止）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| `SKILL.md` の生成 | `skill-toolkit` |
| `plugin.json` の生成 | `plugin-toolkit` |
| マーケットプレイス公開 | `marketplace-publisher` |

## トリガー条件

- 「`{name}` プラグインの README を書いて」「`{name}` の README を更新」
- 「README を最新化」
- 「`{name}` スキルの README が古い」

このスキルを起動しないケース:

- 「`SKILL.md` を作って」（→ `skill-toolkit`）
- 「プラグイン外形を作って」（→ `plugin-toolkit`）

## 前提

- 対象（プラグイン名 or スキル名 or 任意ディレクトリ）
- 対象が既に存在し、内容を読み取り可能

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 既存内容から自動抽出して書き戻し |
| 上記以外 | 対話 | 不明な箇所をユーザに確認 |

## 実行フロー

### 1. 対象種別判定

| 対象 | 判定 |
|-----|------|
| プラグイン名 | `plugins/{plugin}/.claude-plugin/plugin.json` の存在を確認 |
| スキル名 | `skills/{skill}/SKILL.md` の存在を確認 |
| パス指定 | 指定パスの内容を確認 |

### 2. 既存内容のスキャン

| 対象 | スキャン対象 |
|-----|------------|
| プラグイン | `plugin.json`、`commands/`、`skills/`、`agents/`、`hooks/` の内容 |
| スキル | `SKILL.md` のトリガー条件・責務、`references/` のファイル一覧 |

### 3. テンプレート展開

`${CLAUDE_PLUGIN_ROOT}/templates/readme/README.md`（または対象種別に応じたテンプレート）をベースに、スキャンした内容を反映する。

### 4. 各セクションの充填

| セクション | 内容 |
|----------|------|
| 概要 | 1〜2 文で目的を記載 |
| このドキュメントについて | 「人間向けリファレンス・Claude 動作で不参照」を明記 |
| 提供機能 | スキャン結果から自動生成（スキル/コマンド/エージェント一覧） |
| 使い方 | スラッシュコマンド + 自然言語フレーズ例 |
| ファイル構成 | ツリー形式（実構成と一致） |
| 依存システム | 該当時のみ（外部 URL・特定システム参照） |
| カスタマイズ | 編集ポイントの一覧 |

### 5. 過去履歴の除去（更新時）

既存 README に過去履歴・変更経緯・「~~削除済~~」「以前は~~」等の記載がある場合は **削除する**（Git 管理下のため不要）。

### 6. 既存ファイル更新時のエンコーディング維持

エンコーディング・改行コード維持（`~/.claude/rules/common/file-encoding.md`）。

### 7. 検証

- [ ] 「このドキュメントについて」セクションあり
- [ ] ファイル構成が実構成と一致
- [ ] 過去履歴の記載なし
- [ ] プレースホルダ `{...}` 残存なし
- [ ] パスポータビリティ合格

### 8. 引き渡し

- 生成・更新ファイルパス提示
- 関連する変更（提供機能変更等）が他に必要なら案内

## 重要な制約

- **過去履歴・変更経緯・廃止機能の記載禁止**（Git で管理済み）
- 常に最新の実構成と一致させる
- AI 動作で参照されないため、人間可読性を優先（[`../../references/ai-readability.md`](../../references/ai-readability.md) の制約は適用外、ただし命名規則・絵文字禁止は守る）
- 絵文字は使用しない（ユーザ指示なき限り）
- パスポータビリティチェック必須（README 内のパス例も対象）
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md)）
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/conventions.md`](../../references/conventions.md) |
| ポータブルパス | [`../../references/path-portability.md`](../../references/path-portability.md) |
| 検証ルール | [`../../references/validation-rules.md`](../../references/validation-rules.md)（節 1 + 2.7） |
