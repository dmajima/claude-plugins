<!--
NOTE: このファイルはテンプレートです。
本文中の `../../references/...` 等の相対リンクはテンプレート格納場所
（`references/templates/skill/SKILL.md`）からは解決できませんが、これは設計上の意図です。
スキル展開後（`skills/{skill-name}/SKILL.md` にコピー後）に正しく解決されます。
レビュー時は本ファイルでのリンク切れを実害として扱わないでください。
-->
---
name: {skill-name}
description: {主目的の 1 文}。「{トリガーフレーズ例 1}」「{トリガーフレーズ例 2}」「{トリガーフレーズ例 3}」などの依頼で起動する。Use when {english trigger condition}. SKIP when {skip condition} (use {related-skill} for {their responsibility}).
---

# {Skill Title}

{1〜2 文の概要。スキルが何をするか。}

## 責務

- {責務 1}
- {責務 2}
- {責務 3}

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| {業務名} | `{担当スキル名}` |

## トリガー条件

- 「{具体的フレーズ 1}」
- 「{具体的フレーズ 2}」
- 「{具体的フレーズ 3}」

このスキルを起動しないケース:

- {ケース 1}（→ `{他スキル名}`）
- {ケース 2}（→ `{他スキル名}`）

## 前提

呼び出し前に以下が決まっていること:

1. {前提 1}
2. {前提 2}

未確定の場合は {解決方法} を先に行う。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり / 引数で全パラメータ指定 | 非対話 | デフォルト値・引数値で確定し進行 |
| 上記以外 | 対話 | 不足パラメータをユーザに確認 |

## 実行フロー

### 1. {ステップ名}

- 入力: {入力}
- 出力: {出力}
- 参照: [references/{file}.md](references/{file}.md)

{ステップの簡潔な説明}

### 2. {ステップ名}

{ステップの簡潔な説明}

### 3. 検証

- [ ] {検証項目 1}
- [ ] {検証項目 2}

### 4. 引き渡し

{次のスキル / ユーザへの引き渡し内容}

## 重要な制約

- {制約 1}
- {制約 2}
- パスポータビリティチェック必須（[`../../references/path-portability.md`](../../references/path-portability.md)）
- 既存ファイル更新時のエンコーディング維持（`~/.claude/rules/common/file-encoding.md` 不在時は UTF-8 / 元の改行コードを既定維持）
- 利用者環境非依存性の維持（[`../../references/self-containment.md`](../../references/self-containment.md)、ADR-022）
- 第三者レビュー起動時はフレッシュ Agent インスタンスで起動（[`../../references/review-freshness.md`](../../references/review-freshness.md)、ADR-021）
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md)）
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/conventions.md`](../../references/conventions.md) |
| AI 誤認回避規約 | [`../../references/ai-readability.md`](../../references/ai-readability.md) |
| description 設計 | [`../../references/description-guide.md`](../../references/description-guide.md) |
| ポータブルパス | [`../../references/path-portability.md`](../../references/path-portability.md) |
| evals ガイド | [`../../references/eval-guide.md`](../../references/eval-guide.md) |
| 検証ルール | [`../../references/validation-rules.md`](../../references/validation-rules.md) |
| 完了チェックリスト | [`../../references/completion-checklist.md`](../../references/completion-checklist.md) |
| ユーザ対話ルール | [`../../references/user-interaction.md`](../../references/user-interaction.md) |
| バージョン管理 | [`../../references/versioning.md`](../../references/versioning.md) |
| 自己完結性 | [`../../references/self-containment.md`](../../references/self-containment.md) |
| レビューフレッシュ起動原則 | [`../../references/review-freshness.md`](../../references/review-freshness.md) |
