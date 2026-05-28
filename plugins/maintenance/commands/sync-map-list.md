---
description: maintenance sync-settings の全マッピング一覧を表示
argument-hint: "[--show]"
---

`maintenance` プラグインの `sync-settings` スキルが利用するマッピング設定ファイル `~/.claude/.local/plugins/maintenance/sync-mappings.json`（グローバル配下）の全マッピング（global + 全 project）を表示するコマンド。

## 動作

非対話。`${CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync-mappings.sh` を `-Action list` または `-Action show` で実行する。

| 引数 | 動作 |
|------|------|
| なし | `-Action list`（要約表示・1 行ごと） |
| `--show` | `-Action show`（詳細表示・各フィールド全展開） |

## 実行コマンド

```bash
bash "$CLAUDE_PLUGIN_ROOT/skills/sync-settings/references/scripts/sync/sync-mappings.sh" -Action $action
```

<details><summary>PowerShell フォールバック</summary>

```powershell
& chcp.com 65001 | Out-Null; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8;
$action = if ('$ARGUMENTS' -match '--show') { 'show' } else { 'list' }
pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync-mappings.ps1" -Action $action
```

</details>

## 関連

- マッピング設定ファイル: `~/.claude/.local/plugins/maintenance/sync-mappings.json`
- マッピング設定/更新: `/sync-map-set`
- マッピング削除: `/sync-map-delete`
- スキル本体: `sync-settings`
