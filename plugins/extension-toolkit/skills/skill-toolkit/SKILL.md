---
name: skill-toolkit
description: Claude Code のスキル（SKILL.md・references・evals 一式）を新規作成または既存改修するスキル。「新しいスキル foo を作って」「skill foo を更新」「○○用のスキルが欲しい」「既存スキル bar に機能追加」などの依頼で起動する。Use when the user wants to create, scaffold, refactor, or enhance a Claude Code skill. SKIP when the user asks for a plugin shell (use plugin-toolkit), a slash command (use command-toolkit), an agent (use agent-toolkit), a hook (use hook-toolkit), or wants to edit/move existing scripts only (this skill scaffolds the skill envelope, not arbitrary script edits).
---

# Skill Toolkit

Claude Code のスキル一式（`SKILL.md` + `README.md` + `references/` + `evals/`）を新規作成・改修するスキル。プラグイン横断テンプレート（`references/templates/skill/`）と SSOT（`references/`）に従って構造化された生成物を出力する。スキル固有の実行スクリプトが必要な場合は ADR-025 に従い `references/scripts/{業務単位}/` に配置する（スキル直下 `scripts/` は禁止）。

## 責務

- 新規スキルの一式生成（SKILL.md / README.md / references / evals。実行スクリプトは references/scripts/{業務}/）
- 既存スキルの改修（差分追加・分割・整理）
- 依存先プラグイン（`example-skills@anthropic-agent-skills`、`document-skills@anthropic-agent-skills`）の **参照**（必要時のみ）
- プラグイン横断テンプレート（`references/templates/skill/`）のコピー・プレースホルダ置換
- 生成物の構造妥当性検証（行数・必須セクション・パスポータビリティ）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| プラグイン外形（plugin.json・README） | `plugin-toolkit` |
| スラッシュコマンド作成 | `command-toolkit` |
| サブエージェント・チーム作成 | `agent-toolkit` |
| フック作成 | `hook-toolkit` |
| README 単体の生成・更新 | `readme-toolkit` |
| マーケットプレイス公開 | `marketplace-publisher` |
| 完成後のレビュー | `extension-reviewer` |

## トリガー条件

- 「新しいスキル `{name}` を作って」「`{name}` というスキルを作成」
- 「`{name}` スキルを更新」「`{name}` に {機能} を追加」
- 「○○用のスキルが欲しい」（用途のみ指定）
- 「`{name}` スキルを refactor」「`{name}` を分割整理して」

このスキルを起動しないケース:

- 「プラグインを作って」（→ `plugin-toolkit`）
- 「`/cmd` を作って」（→ `command-toolkit`）
- 「エージェントを作って」（→ `agent-toolkit`）

## 前提

呼び出し時に以下が決まっている、または確認可能:

1. スキル名（kebab-case）
2. スキルの目的・トリガー
3. 配置先（スタンドアロン or 既存プラグイン内）
4. 依存外部スキル利用の有無

不足時は対話で確認する。非対話モードでは引数で全て指定する必要がある。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり、または引数で全パラメータ指定 | 非対話 | デフォルト値・引数値で確定し進行 |
| 上記以外 | 対話 | 不足パラメータをユーザに確認 |

## 実行フロー

### 1. モード判定（新規 / 改修）

[references/procedures.md](references/procedures.md) の「モード判定」に従い、新規 or 改修 を確定する。

### 2. テンプレート展開（新規時）

`references/templates/skill/` をコピーし、プレースホルダを置換する。詳細は [references/procedures.md](references/procedures.md) の「新規生成手順」を参照。

### 3. 既存改修（改修時）

[references/procedures.md](references/procedures.md) の「既存改修手順」に従い、差分のみを追加・分割整理する。

### 4. 外部スキル参照の組み込み

ユーザが `example-skills` / `document-skills` の知見を活用したい場合、参照リンクを `references/` に追加する。詳細は [references/external-dependencies.md](references/external-dependencies.md) を参照。

### 5. evals 整備

動作分岐があるスキルは `evals/` を作成する。判定基準は [`../../references/eval-guide.md`](../../references/eval-guide.md) を参照。

### 6. 検証

- [ ] SKILL.md が 200 行以内
- [ ] frontmatter `name` がディレクトリ名と一致
- [ ] description が [`../../references/description-guide.md`](../../references/description-guide.md) の方針に準拠
- [ ] パスポータビリティチェック合格（[`../../references/path-portability.md`](../../references/path-portability.md)）
- [ ] スキル固有スクリプトは `references/scripts/{業務}/` に配置されている（スキル直下 `scripts/` は ADR-025 で禁止）
- [ ] Python 利用時、依存はプラグイン直下 `references/scripts/setup/requirements.txt` に統合され、venv 構築は `environment-setup-toolkit` への委譲が明記されている（ADR-024）
- [ ] `agents/` を重複理由で削除していない
- [ ] 動作分岐がある場合 `evals/` が存在する

### 7. 引き渡し

生成・変更したファイル一覧を提示する。

- `extension-reviewer` への接続を提案（レビュー実施推奨時）
- プラグイン内に配置した場合は `marketplace-publisher` への接続を提案

## 重要な制約

- SKILL.md 200 行超過禁止（超過時は references に分離）
- スキル直下 `scripts/` 禁止、`references/scripts/{業務}/` に配置（ADR-025、`knowledge/` `lib/` `bin/` 不可）
- `agents/` ディレクトリは重複理由で削除しない（プラグイン配布のため）
- 既存ファイル更新時はエンコーディング・改行コード維持（`~/.claude/rules/common/file-encoding.md` 不在時は UTF-8 / 元の改行コードを既定維持）
- パスポータビリティチェック必須
- 利用者環境非依存性の維持（[`../../references/self-containment.md`](../../references/self-containment.md)、ADR-022）
- 第三者レビュー起動時はフレッシュ Agent インスタンスで起動（[`../../references/review-freshness.md`](../../references/review-freshness.md)、ADR-021）
- `git commit` 以降の操作は実行しない
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md)）
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/conventions.md`](../../references/conventions.md) |
| AI 誤認回避 | [`../../references/ai-readability.md`](../../references/ai-readability.md) |
| description 設計 | [`../../references/description-guide.md`](../../references/description-guide.md) |
| ポータブルパス | [`../../references/path-portability.md`](../../references/path-portability.md) |
| evals 作成 | [`../../references/eval-guide.md`](../../references/eval-guide.md) |
| 検証ルール | [`../../references/validation-rules.md`](../../references/validation-rules.md)（節 1 + 2.1） |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| 外部依存スキル | [`references/external-dependencies.md`](references/external-dependencies.md) |
| 動作例 | [`evals/`](evals/) |
