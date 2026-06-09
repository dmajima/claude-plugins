---
name: plugin-toolkit
description: Claude Code プラグイン外形（plugin.json・README）を新規作成し、既存スキル/コマンド/フック/エージェントを移管するスキル。「新しいプラグイン foo を作って」「既存スキル bar をプラグイン化」「スキルをプラグインに変換」等で起動する。Use when scaffolding a new plugin or migrating assets. SKIP when authoring skill/command/agent/hook bodies (skill/command/agent/hook-toolkit), editing marketplace.json (marketplace-toolkit), MIT LICENSE setup (mit-license-toolkit), or publishing (marketplace-publish).
---

# Plugin Toolkit

Claude Code のプラグイン **外形構築 + 既存資産の移管（コピー）** を担当するスキル。プラグイン横断テンプレート（`${CLAUDE_PLUGIN_ROOT}/references/templates/plugin/`）と SSOT（`references/`）に従って構造化された生成物を出力する。

## 責務

- プラグイン外形の生成（`plugins/{plugin-name}/.claude-plugin/plugin.json` + `README.md` + サブディレクトリ）
- 既存スキル/コマンド/フック/エージェントの **コピー配置**
- `settings.json` から該当フックのみ抽出して `hooks.json` 生成
- 配置物の **パスポータビリティチェック**
- 既存プラグインへの追加配置（更新シナリオ）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| スキル本体（SKILL.md・references・scripts・evals）の生成 | `skill-toolkit` |
| スラッシュコマンド本体の生成 | `command-toolkit` |
| サブエージェント・チーム本体の生成 | `agent-toolkit` |
| フック設定本体の生成 | `hook-toolkit` |
| プラグイン・スキル単位の README 生成・更新 | `readme-toolkit` |
| **MIT LICENSE 配置・`plugin.json.license` 設定・`license-info.json` 管理** | `mit-license-toolkit`（ADR-029） |
| マーケットプレイス新規構築 | `marketplace-toolkit` |
| `.claude-plugin/marketplace.json` の編集（plugins[] 追加・更新・削除）+ マーケットプレイス README 同期 | `marketplace-toolkit` |
| プラグイン公開（git push / PR） | `marketplace-publish` |
| 完成後のレビュー | `extension-review` |

## トリガー条件

- 「新しいプラグイン `{name}` を作って」「`{name}` プラグインを作成」
- 「既存スキル `{name}` をプラグイン化」「`{name}` をプラグインに移管」
- 「`{plugin}` プラグインに既存スキル/コマンド/フックを追加」
- 「`settings.json` のフックを `{plugin}` プラグインに切り出し」

このスキルを起動しないケース:

- 「スキル本体を作って」（→ `skill-toolkit`）
- 「コマンド本体を作って」（→ `command-toolkit`）
- 「マーケットプレイスに登録」（→ `marketplace-publish`）

## 前提

呼び出し時に以下が決まっている、または対話で確定可能:

1. プラグイン名（kebab-case）
2. モード（新規外形作成 / 移管 / 既存追加）
3. 移管/追加対象（種別 + 名前、移管時のみ）
4. 配置先プラグイン（既存追加時のみ）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり、または引数で全パラメータ指定 | 非対話 | デフォルト値・引数値で確定し進行 |
| 上記以外 | 対話 | 不足パラメータをユーザに確認 |

## 実行フロー

### 1. シナリオ判定

| シナリオ | 判定条件 |
|---------|---------|
| 新規外形のみ | プラグイン名指定 + 移管対象なし |
| 新規外形 + 中身配置 | プラグイン名指定 + 移管対象あり |
| 既存プラグインへの追加 | プラグイン名 = 既存プラグイン |
| 既存資産のプラグイン化 | スキル/コマンド名指定 + 配置先プラグイン未指定 → 後者を確認 |

詳細は [references/procedures.md](references/procedures.md) の「シナリオ判定」を参照。

### 2. 命名衝突チェック

`plugins/` 配下と `.claude-plugin/marketplace.json` の `plugins[]` を確認し、同名プラグイン存在を検査する。新規作成シナリオで衝突した場合は別名提案 or 更新シナリオ切替をユーザに確認。

### 3. 外形生成（新規時）

`${CLAUDE_PLUGIN_ROOT}/references/templates/plugin/` を `plugins/{plugin-name}/` にコピーし、プレースホルダ置換。詳細は [references/procedures.md](references/procedures.md) の「外形生成手順」を参照。

サブディレクトリは含めるアイテム種別に応じて作成（`commands/` / `skills/` / `agents/` / `hooks/` / `mcp/`）。git は空ディレクトリ保持しないため、実体ファイルが配置される時のみ作成する。

### 4. 既存資産の移管（移管シナリオ）

| 種別 | 変換元 | 変換先 |
|-----|--------|-------|
| スキル | `<src>/.claude/skills/{name}/` | `plugins/{plugin}/skills/{name}/`（ディレクトリ全体） |
| コマンド | `<src>/.claude/commands/{name}.md` | `plugins/{plugin}/commands/{name}.md` |
| エージェント | `<src>/.claude/agents/{name}.md` | `plugins/{plugin}/agents/{name}.md` |
| フック | `<src>/.claude/settings.json` の `hooks` | `plugins/{plugin}/hooks/hooks.json`（該当部分のみ抽出） |

詳細は [references/migration-rules.md](references/migration-rules.md) を参照。

### 5. 既存ファイル更新時のエンコーディング維持

既存ファイル更新時は元ファイルのエンコーディング・改行コードを維持する（`~/.claude/rules/common/file-encoding.md` 不在時は UTF-8 / 元の改行コードを既定維持）。Shift-JIS 等の非 UTF-8 ファイルは Edit/Write を直接使わず Python 経由で書き戻す。

### 6. パスポータビリティチェック

[`../../references/policies/path-portability.md`](../../references/policies/path-portability.md) のルールで配置済み全ファイルを Grep し、NG パスがないか確認。検出時はユーザに修正方針を確認。

### 7. ライセンス配備（必須・ADR-029）

外形生成または既存追加が完了したら、`mit-license-toolkit` を Skill ツール経由で呼び出して MIT LICENSE を配備する。`mit-license-toolkit` が `plugins/{plugin-name}/LICENSE` を生成し、`plugin.json.license = "MIT"` を設定する。ライセンス情報は `<repo_root>/.claude/.local/plugins/extension-toolkit/license-info.json` から取得（複数あれば AskUserQuestion で選択、不在なら新規収集）。詳細は [`../../references/policies/license-policy.md`](../../references/policies/license-policy.md) を参照。

既存プラグインへの追加シナリオ（更新シナリオ）でも、対象プラグインに `LICENSE` が未配置 or `plugin.json.license != "MIT"` を検出した場合は `mit-license-toolkit` を呼び出す。

### 8. 検証

- [ ] `plugin.json` が valid JSON
- [ ] `plugin.json` の `name` がディレクトリ名と一致
- [ ] **`plugin.json` の `license == "MIT"`（ADR-029）**
- [ ] **`plugins/{plugin-name}/LICENSE` が存在し、MIT 標準文 + Copyright 行が埋まっている（ADR-029）**
- [ ] README に未置換プレースホルダ `{...}` が残っていない
- [ ] 移管シナリオで元ファイルが無傷
- [ ] パスポータビリティチェック合格
- [ ] 既存ファイルを誤って上書きしていない
- [ ] **`dependencies` に `marketplace` フィールド付き（クロスマーケットプレイス依存）を含む場合**: README が `readme-policy.md` 5.1 D の D-1 / D-2 / D-3 ブロックを満たすことを `readme-toolkit` 連携時に確認（ADR-028 / [`../../references/policies/dependencies-policy.md`](../../references/policies/dependencies-policy.md) 節 2.3）

### 9. 引き渡し

**作業完了報告の前に必須**: [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) 節 2.4 に従い、ユーザ向け動作デモ（プラグイン読み込み確認・サンプルスキル起動・AskUserQuestion 実発火）を実施し、`AskUserQuestion` で承認を取得する（ADR-032）。

生成・配置したファイル一覧を提示。

| 次のアクション | 接続先 |
|--------------|-------|
| スキル本体未生成（外形のみ作成済み） | `skill-toolkit` |
| コマンド本体未生成 | `command-toolkit` |
| エージェント本体未生成 | `agent-toolkit` |
| フック本体未生成 | `hook-toolkit` |
| README の追加カスタマイズ | `readme-toolkit` |
| LICENSE / `plugin.json.license` 整備 | `mit-license-toolkit`（本フローで連携済みのため通常は不要、再調整時のみ） |
| マーケットプレイス新規構築 | `marketplace-toolkit` |
| `marketplace.json` への登録 + マーケットプレイス README 同期 | `marketplace-toolkit` |
| プラグイン公開（git push / PR） | `marketplace-publish` |
| 全体レビュー | `extension-review` |

## 重要な制約

- 移管対象ファイルは **コピーのみ**（移動禁止、ユーザ明示指示があった場合のみ移動）
- `settings.json` の改変禁止（フック抽出時も元は無傷）
- 同名既存ファイルの **無確認上書き禁止**
- スキルを勝手に分割しない（ユーザ指示なき限り原型を保つ）
- スキル内 `agents/` は重複理由で削除しない（プラグイン配布のため）
- パスポータビリティチェック必須
- 利用者環境非依存性の維持（[`../../references/policies/self-containment.md`](../../references/policies/self-containment.md)、ADR-022）
- 第三者レビュー起動時はフレッシュ Agent インスタンスで起動（[`../../references/checklists/review-freshness.md`](../../references/checklists/review-freshness.md)、ADR-021）
- `git commit` 以降の操作は実行しない
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/guides/user-interaction.md`](../../references/guides/user-interaction.md) + [`../../references/guides/askquestion-strategy.md`](../../references/guides/askquestion-strategy.md)）
- コミットは [`../../references/policies/commit-granularity.md`](../../references/policies/commit-granularity.md) の作業単位ごと分割原則に従う
- 作業完了報告前に [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/policies/conventions-structure.md`](../../references/policies/conventions-structure.md) |
| AI 誤認回避 | [`../../references/policies/ai-readability.md`](../../references/policies/ai-readability.md) |
| ポータブルパス | [`../../references/policies/path-portability.md`](../../references/policies/path-portability.md) |
| 検証ルール | [`../../references/checklists/validation-rules.md`](../../references/checklists/validation-rules.md)（節 1 + 2.2） |
| バージョン管理 | [`../../references/policies/versioning.md`](../../references/policies/versioning.md)（`plugin.json` 編集時必須）|
| 依存関係宣言 | [`../../references/policies/dependencies-policy.md`](../../references/policies/dependencies-policy.md)（`dependencies` 設定 + クロスマーケ依存時の README 連携要件）|
| README 規約（クロスマーケ依存時 D-1/D-2/D-3 必須）| [`../../references/policies/readme-policy.md`](../../references/policies/readme-policy.md) 節 5.1 D / ADR-028 |
| ライセンス必須化（MIT）| [`../../references/policies/license-policy.md`](../../references/policies/license-policy.md) / ADR-029 |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| 移管ルール | [`references/migration-rules.md`](references/migration-rules.md) |
| 動作例 | [`evals/`](evals/) |
