---
name: skill-creator
description: Claude Code のスキル（SKILL.md・references・scripts・evals 一式）を新規作成または既存改修するスキル。「新しいスキル foo を作って」「skill foo を更新」「○○用のスキルが欲しい」「既存スキル bar に機能追加」などの依頼で起動する。Use when the user wants to create, scaffold, refactor, or enhance a Claude Code skill. SKIP when the user asks for a plugin shell (use plugin-creator), a slash command (use command-creator), an agent (use agent-creator), or a hook (use hook-creator).
---

# Skill Creator

Claude Code のスキル（`SKILL.md` + `README.md` + `references/` + `scripts/` + `evals/`）を新規作成・改修するスキル。プラグイン横断テンプレート（`templates/skill/`）と SSOT（`references/`）に従って構造化された生成物を出力する。

## 責務

- 新規スキルの一式生成（SKILL.md / README.md / references / scripts / evals）
- 既存スキルの改修（差分追加・分割・整理）
- 依存先プラグイン（`example-skills@anthropic-agent-skills`、`document-skills@anthropic-agent-skills`）の **参照**（必要時のみ）
- プラグイン横断テンプレート（`templates/skill/`）のコピー・プレースホルダ置換
- 生成物の構造妥当性検証（行数・必須セクション・パスポータビリティ）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| プラグイン外形（plugin.json・README） | `plugin-creator` |
| スラッシュコマンド作成 | `command-creator` |
| サブエージェント・チーム作成 | `agent-creator` |
| フック作成 | `hook-creator` |
| README 単体の生成・更新 | `readme-creator` |
| マーケットプレイス公開 | `marketplace-publisher` |
| 完成後のレビュー | `extension-reviewer` |

## トリガー条件

- 「新しいスキル `{name}` を作って」「`{name}` というスキルを作成」
- 「`{name}` スキルを更新」「`{name}` に {機能} を追加」
- 「○○用のスキルが欲しい」（用途のみ指定）
- 「`{name}` スキルを refactor」「`{name}` を分割整理して」

このスキルを起動しないケース:

- 「プラグインを作って」（→ `plugin-creator`）
- 「`/cmd` を作って」（→ `command-creator`）
- 「エージェントを作って」（→ `agent-creator`）

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

`templates/skill/` をコピーし、プレースホルダを置換する。詳細は [references/procedures.md](references/procedures.md) の「新規生成手順」を参照。

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
- [ ] `scripts/` の業務単位サブフォルダ構造が正しい
- [ ] Python 利用時 `setup_venv.sh` / `teardown_venv.sh` / `requirements.txt` が揃っている
- [ ] `agents/` を重複理由で削除していない
- [ ] 動作分岐がある場合 `evals/` が存在する

### 7. 引き渡し

生成・変更したファイル一覧を提示する。

- `extension-reviewer` への接続を提案（レビュー実施推奨時）
- プラグイン内に配置した場合は `marketplace-publisher` への接続を提案

## 重要な制約

- SKILL.md 200 行超過禁止（超過時は references に分離）
- `scripts/` 命名固定（`knowledge/` 不可）
- `agents/` ディレクトリは重複理由で削除しない（プラグイン配布のため）
- 既存ファイル更新時はエンコーディング・改行コード維持（`~/.claude/rules/common/file-encoding.md`）
- パスポータビリティチェック必須
- `git commit` 以降の操作は実行しない

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
