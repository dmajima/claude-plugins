---
name: marketplace-toolkit
description: Claude Code プラグインマーケットプレイス（.claude-plugin/marketplace.json）の新規構築・本体管理（manifest・README 同期）スキル。「マーケットプレイス foo を作って」「marketplace.json に bar を追加」「README を同期」等で起動する。Use when creating or updating a marketplace. SKIP when publishing (marketplace-publish), building plugin body (plugin-toolkit), or MIT LICENSE setup (mit-license-toolkit).
---

# Marketplace Toolkit

Claude Code のプラグインマーケットプレイス（`.claude-plugin/marketplace.json` を持つリポジトリ）の **新規構築** および **本体管理**（`marketplace.json` 編集 + マーケットプレイス README 同期）を担当するスキル。プラグインの公開ワークフロー（git push / PR）は `marketplace-publish` に委譲する（ADR-020 準拠）。

## 責務

- マーケットプレイスの新規構築（リポジトリ初期化 + `.claude-plugin/marketplace.json` + マーケットプレイス README + `.gitignore`）
- 既存マーケットプレイスへのプラグイン追加・更新・削除（`marketplace.json` の `plugins[]` 編集）
- マーケットプレイス直下 README の生成・同期（ADR-019 準拠、プラグイン一覧テーブル維持）
- `allowCrossMarketplaceDependenciesOn` 等のマーケットプレイス設定管理

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| プラグイン外形作成 | `plugin-toolkit` |
| プラグイン公開（git push / PR） | `marketplace-publish` |
| 通常の README 生成（プラグイン・スキル単位） | `readme-toolkit` |
| 環境構築 | `environment-setup-toolkit` |

## トリガー条件

- 「新しいマーケットプレイス `{name}` を作って」「マーケットプレイスを構築」
- 「`marketplace.json` に `{plugin}` を追加」「マーケットプレイスのプラグイン一覧を更新」
- 「マーケットプレイス README を更新」「マーケットプレイス README を同期」

このスキルを起動しないケース:

- 「`{plugin}` プラグインを公開」（→ `marketplace-publish`、内部で本スキルを呼ぶ）
- 「`{plugin}` プラグインを作って」（→ `plugin-toolkit`）

## 前提

- 対象マーケットプレイス名（kebab-case）
- リポジトリ URL（新規構築時）または既存ローカルパス（更新時）
- `marketplace.json` の owner / description 情報（新規構築時）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 既存パスに `.claude-plugin/marketplace.json` なし | 新規構築 | テンプレート展開 + 初期化 |
| 既存パスに `marketplace.json` あり + `--add-plugin` 等 | プラグイン追加 | `plugins[]` にエントリ追加 + README 同期 |
| 既存パスに `marketplace.json` あり + `--update-plugin` 等 | プラグイン更新 | エントリ更新 + README 同期 |
| 既存パスに `marketplace.json` あり + `--remove-plugin` 等 | プラグイン削除 | エントリ削除 + README 同期 |
| 既存パスに `marketplace.json` あり + `--sync-readme` | README 同期のみ | `marketplace.json` の現状から README 再生成 |
| `--non-interactive` フラグ | 非対話 | 必須引数を全フラグで受け取り、対話なしで実行 |

## 実行フロー

### 1. モード判定 + 入力検証

[references/operations.md](references/operations.md) の判定ロジックに従いモード確定。
新規構築モードでは `name` / `owner` / `description` を必須入力として確認。

### 2. テンプレート展開（新規構築時のみ）

[`../../references/templates/marketplace/`](../../references/templates/marketplace/) を対象ディレクトリにコピー:

| 生成ファイル | テンプレート |
|-----------|-----------|
| `.claude-plugin/marketplace.json` | `templates/marketplace/.claude-plugin/marketplace.json` |
| `README.md` | `templates/marketplace/README.md` |
| `.gitignore` | 新規生成（`.claude/.local/` 等を含む） |

### 3. marketplace.json 編集

| シナリオ | 動作 |
|---------|------|
| 新規構築 | テンプレートのプレースホルダを置換（`{marketplace-name}` / `{owner-name}` / `{description}` 等） |
| プラグイン追加 | `plugins[]` にエントリ追加（`name` / `source` / `description`）。アルファベット順に挿入 |
| プラグイン更新 | 該当エントリの `description` / `source` を更新 |
| プラグイン削除 | 該当エントリを削除（ユーザ明示確認必須） |

JSON 整合性は編集後に必ず検証（[`../../references/checklists/validation-rules.md`](../../references/checklists/validation-rules.md) 節 2.8）。

### 4. マーケットプレイス README 同期（ADR-019 準拠）

`marketplace.json` の現状から README のプラグイン一覧テーブルを再生成。テーブル列:

| 列 | 値の取得元 |
|---|----------|
| プラグイン名 | `marketplace.json` の `plugins[].name` |
| 説明 | `marketplace.json` の `plugins[].description` |
| バージョン | 各プラグインの `plugin.json` から **直接転記** |
| インストール | `/plugin install {name}@{marketplace-name}` の固定形式 |

詳細は [references/readme-sync.md](references/readme-sync.md) を参照。

### 5. 検証

- [ ] `marketplace.json` JSON valid
- [ ] `name` がディレクトリ名と一致
- [ ] `plugins[]` 各エントリの `source` パスが実在
- [ ] README のプラグイン一覧テーブルが `marketplace.json` と完全一致（行数・名前・バージョン）
- [ ] README 必須セクション（[`../../references/policies/readme-policy.md`](../../references/policies/readme-policy.md) 節 11.1）が揃う
- [ ] [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) に基づく自己検証

### 6. 引き渡し

**作業完了報告の前に必須**: [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) 節 2.4 に従い、`marketplace.json` JSON 妥当性確認 + 同期 README の到達性確認を実施し、`AskUserQuestion` で承認を取得する（ADR-032）。

| 結果 | 接続先 |
|-----|-------|
| 新規構築完了 | `plugin-toolkit` への接続提案（最初のプラグイン作成） |
| プラグイン追加・更新完了 | `marketplace-publish` への接続提案（公開フロー） |
| README 同期のみ完了 | コミット案内のみ（`marketplace-publish` のフルオートを使う場合は連携可） |

## 重要な制約

- `marketplace.json` の編集と **同一の操作内** で必ず README を同期する（ADR-019 違反を防ぐ）
- バージョン情報は `marketplace.json` には持たず、各プラグインの `plugin.json` を正典とする
- プラグイン削除はユーザの **明示的確認** を必須とする（誤削除防止）
- **ファイル本体削除（`--also-delete-files`）は `--confirm-destructive` との二段フラグでのみ受理**（非対話モードでも本制約は維持、対話モードでは追加で `AskUserQuestion` 二重確認）
- 新規構築時の `<target-path>` はシステムパス・ホームディレクトリ等の拒否リストと照合（パストラバーサル対策、[references/operations.md](references/operations.md) の検証ロジック）
- `marketplace.json` の `plugins[].source` は `./plugins/` プレフィックス必須（パストラバーサル対策）
- パスポータビリティチェック必須（[`../../references/policies/path-portability.md`](../../references/policies/path-portability.md)）
- エンコーディング・改行コード維持必須（`~/.claude/rules/common/file-encoding.md` 不在時は UTF-8 / 元の改行コードを既定維持）
- 利用者環境非依存性の維持（[`../../references/policies/self-containment.md`](../../references/policies/self-containment.md)、ADR-022）
- 第三者レビュー起動時はフレッシュ Agent インスタンスで起動（[`../../references/checklists/review-freshness.md`](../../references/checklists/review-freshness.md)、ADR-021）
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/guides/user-interaction.md`](../../references/guides/user-interaction.md) + [`../../references/guides/askquestion-strategy.md`](../../references/guides/askquestion-strategy.md)）
- 作業完了報告前に [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) に基づく自己検証を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/policies/conventions-structure.md`](../../references/policies/conventions-structure.md) |
| README 規約（マーケットプレイス節） | [`../../references/policies/readme-policy.md`](../../references/policies/readme-policy.md)（節 11.1） |
| 検証ルール | [`../../references/checklists/validation-rules.md`](../../references/checklists/validation-rules.md)（節 1 + 2.8） |
| バージョン管理 | [`../../references/policies/versioning.md`](../../references/policies/versioning.md)（`marketplace.json` 編集時のプラグインバージョン同期確認）|
| 操作詳細 | [`references/operations.md`](references/operations.md) |
| README 同期詳細 | [`references/readme-sync.md`](references/readme-sync.md) |
| テンプレート | [`../../references/templates/marketplace/`](../../references/templates/marketplace/) |
| 動作例 | [`evals/`](evals/) |
