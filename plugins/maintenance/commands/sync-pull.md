---
description: maintenance sync-settings のマッピングに従って pull 同期
argument-hint: "[--scope <global|project>] [--strategy <overwrite|merge|skip>] [--dry-run] [--no-backup] [--prune] [--yes]"
---

`maintenance` プラグインの `sync-settings` スキルが利用するマッピング設定 `sync-mappings.json` に従って、リモート Git リポジトリから `~/.claude/` または `<project>/.claude/` 配下を **pull 同期** するコマンド。

**前提**: 事前に `/sync-map-set` で対象スコープのマッピングを設定しておく必要がある。

`$ARGUMENTS` の有無により **2 つの動作モード** を切り替える（Phase 3-C-α では非対話モードのみ実装、対話モードは Phase 3-C-β で対応）。

## 非対話モード（`$ARGUMENTS` が非空 or Phase 3-C-α 既定）

引数を解析し、`${CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync.ps1 -Mapping <scope>` を実行する。

| 引数 | 動作 |
|------|------|
| `--scope <global\|project>` | 対象スコープ。`sync-mappings.json` から該当マッピングを取得して sync.ps1 に渡す |
| `--strategy <overwrite\|merge\|skip>` | 同期戦略（既定 overwrite。Phase 3-C-β で `interactive` 追加予定）|
| `--dry-run` | ドライラン（差分プレビューのみ・実適用なし） |
| `--no-backup` | バックアップなし（既定はバックアップ取得） |
| `--prune` | overwrite 戦略時、リモートに存在しないローカルファイルを削除 |
| `--yes` | AskUserQuestion 確認をスキップして実適用 |

実行例:

```powershell
& chcp.com 65001 | Out-Null; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8;

# 引数から --scope を抽出
$scope = ''
if ('$ARGUMENTS' -match '--scope\s+(global|project)') { $scope = $matches[1] }

# sync.ps1 に -Mapping <scope> 形式で渡す（その他の引数も継承）
pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync.ps1" -Mapping $scope $ARGUMENTS
```

## マッピング未設定時のエラー

`--scope <scope>` を指定したが `sync-mappings.json` に該当マッピングがない場合、sync.ps1 は以下のエラーで終了する:

```
Mapping '<scope>' に対応するマッピングが sync-mappings.json に存在しません。/sync-map-set で設定してください。
```

ユーザに `/sync-map-set` での設定を促す。

## 対話モード（将来）

Phase 3-C-β で実装予定:

- AskUserQuestion で scope / strategy を確認
- `interactive` 戦略時は差分 1 件ごとに AskUserQuestion で「上書き / 保持 / スキップ / 全件 overwrite / キャンセル」を確認

## 関連

- マッピング設定/更新: `/sync-map-set`
- マッピング一覧: `/sync-map-list`
- マッピング削除: `/sync-map-delete`
- スキル本体: `sync-settings`
- push 同期（将来）: `/sync-push`（Phase 3-D で実装予定）
