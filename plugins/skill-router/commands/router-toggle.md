---
description: skill-router を一時停止／再開（ルーティング on/off を即時切替）
argument-hint: "<on|off>"
---

ユーザの引数: $ARGUMENTS

`skill-router` のルーティング動作を即時に切り替えます。`<base>/disabled` フラグファイルの作成・削除で実現するため、Claude Code の再起動なしで反映されます（`references/scripts/hooks/route_prompt.sh` のトグル参照順位と整合）。

## 動作モード

| 引数 | 動作 |
|-----|------|
| `on` | `<base>/disabled` を削除（存在すれば）し、ルーティングを有効化 |
| `off` | `<base>/disabled` を作成し、ルーティングを無効化 |
| 空 / その他 | 現在の状態（ON/OFF）を表示し、引数 `on` / `off` のいずれかを指定するよう案内 |

## base ディレクトリ解決

```text
1. CLAUDE_PLUGIN_DATA （定義され書込可能なら最優先）
2. <repo-root>/.claude/.local/plugins/skill-router/
3. <user-home>/.claude/.local/plugins/skill-router/
```

`<user-home>` は `$USERPROFILE`（または `$HOME`）として解決します（Windows / Unix 互換のため、credentials-manager と統一）。書き込み先は **解決順位の 1 番目** を使用します（`route_prompt.sh` のトグル参照順位と一致）。

## 実行手順

トグル本体ロジックは `references/scripts/commands/toggle.sh` に集約しています（ADR-025 / scripts-policy 準拠）。

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/commands/toggle.sh" status
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/commands/toggle.sh" off
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/commands/toggle.sh" on
```

| 引数 | 動作 |
|-----|------|
| `status` | 現在の状態（ON / OFF）を 1 行で表示 |
| `off` | 解決順位 1 番目に `disabled` ファイルを作成 |
| `on` | 全層から `disabled` ファイルを削除 |

スクリプトは fail-open（exit 0）で、書込権限不足等の異常もブロックしません。

## 提示する内容

- 切替前後の状態（ON / OFF）
- 操作したフラグファイルパス
- 補足: 「`route_prompt.sh` は次回プロンプト送信時から新状態で動作」

## 失敗時

- 書込権限エラーの場合はパスをユーザに提示し、別 base ディレクトリでの実行を提案する。
- `off` を複数回連続実行した場合はべき等（既存フラグを上書き）。
- `on` を複数回連続実行した場合もべき等（フラグ不在ならスキップ）。

## 補足

- 再有効化は `on` 引数だけでなく、対応する `disabled` ファイルを直接削除しても可能。
- 永続的に無効化したい場合は `~/.claude/settings.json` の `enabledPlugins` から `skill-router@dmajima-claude-plugins` を外す方が確実。
