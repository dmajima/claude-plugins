# Agent Teams（チーム定義）

`extension-toolkit` プラグインに同梱されるエージェントチームの一覧。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各チームの動作本体は対応する `*.md` ファイルおよび `extension-reviewer` スキルから参照されます。

## チーム一覧

| チーム名 | 用途 | リード | 人数 |
|---------|------|-------|-----|
| [`plugin-review-team`](plugin-review-team.md) | プラグイン横断レビュー | `architect` | 4〜5（フック有無で変動） |
| [`skill-review-team`](skill-review-team.md) | スキル単体レビュー | `plugin-structure-reviewer` | 3 |
| [`hook-security-team`](hook-security-team.md) | フックセキュリティレビュー | `security-engineer` | 3 |

## チームサイズの原則

- **標準**: 3〜5 名（最低 3 名）
- **例外**: 観点が 2 つしか想定できない場合は 2 名でも可（例: 性別観点で「男 / 女」のみ）。理由をチーム定義に明記する
- **最大**: 5 名（議論調整コストの上限）

## 構成エージェント

各チームは「グローバル既存エージェント（`~/.claude/agents/`）」と「プラグイン同梱エージェント（`agents/`）」の組み合わせで編成される。

| 種別 | 配置 |
|-----|------|
| グローバル | `~/.claude/agents/{name}.md` |
| プラグイン同梱 | `plugins/extension-toolkit/agents/{name}.md` |

詳細は [`../references/agent-utilization.md`](../references/agent-utilization.md) を参照。

## 起動方法

`extension-reviewer` スキルが対象種別に応じて適切なチームを選定し起動する。各 `*-toolkit` スキルが直接呼ぶ場合は `agent-toolkit` の team-design パターンに従う。

## 関連スキル

| スキル | 関係 |
|-------|------|
| `extension-reviewer` | これらのチームを起動するオーケストレータ |
| `agent-toolkit` | チーム新規作成・改修を担当 |
