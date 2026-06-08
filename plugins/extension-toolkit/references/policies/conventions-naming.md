# 命名・ファイル形式規約

`extension-toolkit` プラグイン配下の全スキル・全成果物が従うべき命名・ファイル形式規約。

階層別の厳格度:

| 階層 | 厳格度 | 内容 |
|-----|-------|------|
| プラグイン直下 | **厳格（許可リスト運用）** | 列挙されたディレクトリ・ファイル以外を置かない |
| スキル直下 | **厳格（許可リスト運用）** | 同上 |
| `references/` 直下 | 推奨例（緩い） | 推奨される命名・配置を例示。実情に応じて拡張可 |
| `scripts/` 直下 | 推奨例（緩い） | 推奨される業務単位サブフォルダを例示。`knowledge/` 等の禁止項目のみ厳格 |

本ファイルは命名・ファイル形式に特化した規約（旧 `conventions.md` 節 1・6・7 に対応）。構造規約（節 2〜5）は [`conventions-structure.md`](conventions-structure.md)、共通規約・禁止事項（節 8〜14）は [`conventions-general.md`](conventions-general.md) を参照。

## 1. 命名規約

| 対象 | 形式 | 例 |
|-----|------|---|
| プラグイン名 | kebab-case | `extension-toolkit` |
| スキル名 | kebab-case（`SKILL.md` の `name` と一致） | `skill-toolkit` |
| コマンド名 | kebab-case（拡張子 `.md` を除く） | `extension` |
| エージェント名 | kebab-case | `code-reviewer` |
| エージェントチーム名 | kebab-case | `skill-review-team` |
| フックファイル | `hooks.json` 固定 | `hooks/hooks.json` |
| references 配下のドキュメント | kebab-case + 用途名 | `references/conventions.md` |
| evals ケースファイル | `case-{2 桁番号}_{snake_case 名}.md` | `case-01_new_skill_interactive.md` |

禁止される命名:

| 禁止 | 理由 | 代替 |
|-----|------|------|
| `knowledge/`（スクリプト保管用） | 規約違反 | `scripts/` |
| `shared/`（プラグイン横断 SSOT） | 規約違反 | `references/` |
| CamelCase / snake_case のディレクトリ名 | エコシステム慣用に反する | kebab-case |
| `§` 記号を含むファイル名・本文 | 文書ルール違反 | `1.` / `セクション1` / `第1節` |

## 6. コマンドファイル構造

```markdown
---
description: コマンドの 1 行説明（60 文字以内）
argument-hint: <必須引数> [省略可引数] [--flag 値]
---

実行内容のプロンプト。$ARGUMENTS でユーザ引数を受け取る。
```

| ルール | 内容 |
|-------|------|
| frontmatter `description` | 60 文字以内 |
| frontmatter `argument-hint` | 引数を受け取るコマンドは **必須**（ADR-023 / [`../guides/description-guide.md`](../guides/description-guide.md) 節 4.1） |
| 引数仕様 | description ではなく `argument-hint` と本文に書く（`argument-hint` が SSOT） |

## 7. エージェントファイル構造

```markdown
---
name: {agent-name}
description: いつ使うかの説明
model: sonnet
tools: {許可ツールのカンマ区切りリスト}
---

# {役割名}

## ロール定義
## 専門性
## 評価観点
## 出力フォーマット
## プロンプトテンプレート
```

| 必須セクション | 内容 |
|------------|------|
| ロール定義 | 1〜3 文の役割記述 |
| 専門性 | 専門領域 / 評価軸 / 参照する外部知識 |
| 評価観点 | 3 項目以上のチェックリスト |
| 出力フォーマット | Critical / High / Medium / Low / 総合判定の構造 |
| プロンプトテンプレート | 起動時に渡すプロンプトのひな形 |