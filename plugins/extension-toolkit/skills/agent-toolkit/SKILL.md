---
name: agent-toolkit
description: Claude Code のサブエージェント（agents/{name}.md）・エージェントチームを新規作成・編成・改修するスキル。「コードレビュー用エージェントを作って」「セキュリティ評価チームを編成」「実装エンジニア視点のエージェントが欲しい」等で起動する。Use when creating or refactoring a sub-agent or team. SKIP when target is a skill (skill-toolkit), command (command-toolkit), hook (hook-toolkit), plugin shell (plugin-toolkit), or MIT LICENSE setup (mit-license-toolkit).
---

# Agent Toolkit

Claude Code のサブエージェント単体・エージェントチームを設計・作成するスキル。要件に合わせて専門性のあるエージェントを選定し、デファクトスタンダードや外部リファレンスを取り入れた設計を行う。

## 責務

- サブエージェント単体の作成（`agents/{name}.md`）
- エージェントチームの編成（リード + メンバー、最低 3 名）
- 専門領域・評価観点・出力フォーマット・プロンプトテンプレートの設計
- 既存エージェント（`~/.claude/agents/` 配下）との重複チェック・統合提案
- レビュー系チームでの **観点網羅性** の検証（最低 3 観点・3 名以上）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| スキル本体の生成 | `skill-toolkit` |
| プラグイン外形の生成 | `plugin-toolkit` |
| スラッシュコマンド生成 | `command-toolkit` |
| フック設定の生成 | `hook-toolkit` |
| README 単体の生成 | `readme-toolkit` |
| マーケットプレイス公開 | `marketplace-publisher` |

## トリガー条件

- 「`{name}` エージェントを作って」「`{name}` 視点のエージェントが欲しい」
- 「{用途} 用のエージェントチームを編成」
- 「コードレビューチームを作って」「セキュリティ評価チームを設計」
- 「既存エージェント `{name}` を改修」

このスキルを起動しないケース:

- 「スキルを作って」（→ `skill-toolkit`）
- 「プラグインを作って」（→ `plugin-toolkit`）
- 「フック設定を作って」（→ `hook-toolkit`）

## 前提

呼び出し時に以下が決まっている、または対話で確定可能:

1. モード（単体エージェント / チーム編成）
2. エージェント名 or チーム名（kebab-case）
3. 専門領域・主な評価観点
4. 配置先（グローバル `~/.claude/agents/` or プラグイン内 `agents/`）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり、または引数で全パラメータ指定 | 非対話 | デフォルト値・引数値で確定し進行 |
| 上記以外 | 対話 | 不足パラメータをユーザに確認 |

## 実行フロー

### 1. モード判定（単体 / チーム）

| 入力の特徴 | モード |
|----------|-------|
| 1 名の役割が指定 | 単体エージェント |
| 「チーム」「複数視点」「議論」を含む発話 | チーム編成 |
| `--team` フラグあり | チーム編成 |
| レビュー系（観点網羅が必要） | チーム編成（最低 3 名） |

詳細は [references/procedures.md](references/procedures.md) の「モード判定」を参照。

### 2. 既存エージェント確認

`~/.claude/agents/` および対象プラグインの `agents/` を Glob で確認。重複候補を提示し、統合 or 新規作成の判断をユーザに仰ぐ。

詳細は [references/team-design.md](references/team-design.md) の「重複チェック」を参照。

### 3. 専門性・評価観点の設計

ユーザの要件から専門領域を抽出し、評価観点を設計する。デファクトスタンダード・外部リファレンスを取り入れる。

| 領域 | 参照すべき外部知識 |
|-----|-----------------|
| セキュリティ | OWASP Top 10、STRIDE、CWE |
| アクセシビリティ | WCAG、ARIA |
| 可用性 | SRE Book、SLO/SLI |
| 法務 | OSS ライセンス互換性、GDPR |
| コード品質 | Clean Code、SOLID 原則 |
| その他 | 領域固有のベストプラクティス・標準 |

### 4. テンプレート展開

| モード | テンプレート |
|-------|------------|
| 単体エージェント | `${CLAUDE_PLUGIN_ROOT}/references/templates/agent/agent.md` |
| チーム編成 | `${CLAUDE_PLUGIN_ROOT}/references/templates/agent/team.md` |

プレースホルダ置換は [references/procedures.md](references/procedures.md) を参照。

### 5. プロンプトテンプレート充填

エージェントのプロンプトテンプレートに以下を含める:

- ロール定義（1〜3 文）
- 評価観点（チェックリスト）
- 出力フォーマット（Critical/High/Medium/Low の重大度別）
- 参照する外部知識・標準

### 6. チーム編成時の追加検証（チームモード）

- [ ] メンバー数 3 名以上（レビュー系は最低 3 名）
- [ ] リードエージェントが指定されている
- [ ] メンバーの専門性が **重複なく相補的** である
- [ ] 評価観点が **網羅的** である（盲点がないか確認）
- [ ] 議論ラウンド数（最低 3 回）が指定されている

詳細は [references/team-design.md](references/team-design.md) を参照。

### 7. 検証

- [ ] frontmatter `name` `description` `model` `tools` 全て指定
- [ ] description が [`../../references/guides/description-guide.md`](../../references/guides/description-guide.md) のエージェント向けルール準拠
- [ ] 評価観点が 3 つ以上
- [ ] 出力フォーマットが定義されている
- [ ] パスポータビリティ合格

### 8. 引き渡し

**作業完了報告の前に必須**: [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) 節 2.4 に従い、ユーザ向け動作デモ（チーム編成時はチームメンバー実起動 1 回以上、単体エージェントは Agent ツールで実起動 1 回）を実施し、`AskUserQuestion` で承認を取得する（ADR-032）。

- 生成ファイルパスを提示
- チーム編成時はスポーンプロンプト例も提示
- プラグイン内配置時は `marketplace-publisher` への接続を提案

## 重要な制約

- レビュー系チームは **最低 3 名・3 観点以上**
- メンバーの専門性は重複なく相補的
- 既存エージェントとの重複は必ずユーザに提示
- スキル内 `agents/` のグローバル重複削除禁止（プラグイン配布のため）
- パスポータビリティチェック必須
- 利用者環境非依存性の維持（[`../../references/policies/self-containment.md`](../../references/policies/self-containment.md)、ADR-022）
- 第三者レビュー起動時はフレッシュ Agent インスタンスで起動（[`../../references/checklists/review-freshness.md`](../../references/checklists/review-freshness.md)、ADR-021）
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/guides/user-interaction.md`](../../references/guides/user-interaction.md) + [`../../references/guides/askquestion-strategy.md`](../../references/guides/askquestion-strategy.md)）
- 作業完了報告前に [`../../references/checklists/completion-checklist.md`](../../references/checklists/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/policies/conventions-structure.md`](../../references/policies/conventions-structure.md) |
| description 設計 | [`../../references/guides/description-guide.md`](../../references/guides/description-guide.md) |
| 検証ルール | [`../../references/checklists/validation-rules.md`](../../references/checklists/validation-rules.md)（節 1 + 2.4 / 2.5） |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| チーム設計ルール | [`references/team-design.md`](references/team-design.md) |
| 動作例 | [`evals/`](evals/) |
