# readme-toolkit (skill)

Claude Code のプラグイン・スキル等の `README.md`（人間向けリファレンス）を作成・更新するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。

## 責務（要約）

`README.md` の生成・更新のみ。`SKILL.md` 等の本体は他スキルが担当。

## 設計方針

- 常に最新の実構成と一致させる
- 過去履歴・変更経緯の記載禁止（Git 管理）
- 「このドキュメントについて」セクションで AI 動作で不参照と明記

## トリガー例

- 「`dev-toolkit` プラグインの README を書いて」
- 「`code-formatter` スキルの README を最新化」

## 関連スキル

| スキル | 関係 |
|-------|------|
| `skill-toolkit` | スキル本体作成後に README 生成 |
| `plugin-toolkit` | プラグイン外形作成後に README 生成 |
| `extension-reviewer` | README の整合性レビュー |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
