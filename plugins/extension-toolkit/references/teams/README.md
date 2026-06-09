# Agent Teams（チーム定義）

`extension-toolkit` プラグインに同梱されるエージェントチームの一覧。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各チームの動作本体は対応する `*.md` ファイルおよび `extension-review` スキルから参照されます。

## チーム一覧

| チーム名 | 用途 | リード | 人数 |
|---------|------|-------|-----|
| [`plugin-review-team`](plugin-review-team.md) | プラグイン横断レビュー | `architect` | 5〜6（フック有無で変動、リード含む） |
| [`skill-review-team`](skill-review-team.md) | スキル単体レビュー | `plugin-structure-reviewer` | 3（リード含む） |
| [`hook-security-team`](hook-security-team.md) | フックセキュリティレビュー | `security-engineer` | 3（リード含む） |

## チームサイズの原則

- **標準**: 3〜5 名（最低 3 名、リード含む）
- **例外**:
  - 観点が 2 つしか想定できない場合は 2 名でも可（例: 性別観点で「男 / 女」のみ）。理由をチーム定義に明記する
  - 観点網羅が必要なプラグイン全体レビューは最大 6 名まで許容（フック含有時の `plugin-review-team`）
- **最大**: 標準 5 名、上記の例外時 6 名（議論調整コストの上限）

## 構成エージェント

各チームは「グローバル既存エージェント（`~/.claude/agents/`）」と「プラグイン同梱エージェント（`agents/`）」の組み合わせで編成される。

| 種別 | 配置 |
|-----|------|
| グローバル | `~/.claude/agents/{name}.md` |
| プラグイン同梱 | `plugins/extension-toolkit/agents/{name}.md` |

詳細は [`../agent-utilization.md`](../agent-utilization.md) を参照。

## 起動方法

`extension-review` スキルが対象種別に応じて適切なチームを選定し起動する。各 `*-toolkit` スキルが直接呼ぶ場合は `agent-toolkit` の team-design パターンに従う。

## 関連スキル

| スキル | 関係 |
|-------|------|
| `extension-review` | これらのチームを起動するオーケストレータ |
| `agent-toolkit` | チーム新規作成・改修を担当 |
