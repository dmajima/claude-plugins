---
description: maintenance sync-settings のマッピングを削除
argument-hint: "[--scope <global|project>] [--project-path <path>] [--force]"
---

`maintenance` プラグインの `sync-settings` スキルが利用するマッピング設定ファイルから、指定スコープのマッピングを削除する。誤削除防止のため、対話モードでは AskUserQuestion で対象確認 + 削除確認の 2 段階確認を実施。

`$ARGUMENTS` の有無により **2 つの動作モード** を切り替える。

## 1. 非対話モード（`$ARGUMENTS` が非空）

引数を解析し、`${CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync-mappings.ps1 -Action delete -Force` を実行する。

| 引数 | 動作 |
|------|------|
| `--scope global` | global マッピングを削除（`--force` 必須） |
| `--scope project [--project-path <path>]` | 指定 project マッピングを削除（path 省略時はカレントディレクトリのリポジトリルート、`--force` 必須） |
| `--force` | 確認スキップ（非対話モード必須） |

実行例:

`$ARGUMENTS` の文字列を直接 sync-mappings.ps1 に展開するのは引数インジェクションの
余地が残るため、**個別フラグを明示的にパースして名前付き引数で渡す**こと。

```powershell
& chcp.com 65001 | Out-Null; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8;

$argText = '$ARGUMENTS'
$params  = @{ Action = 'delete' }

if ($argText -match '--scope\s+(global|project)\b')                       { $params.Scope       = $matches[1] }
if ($argText -match '--project-path\s+"([^"]+)"|--project-path\s+(\S+)')  { $params.ProjectPath = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }
if ($argText -match '\B--force\b')                                        { $params.Force       = $true }

pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync-mappings.ps1" @params
```

> **note**: `--force` が引数に含まれていない場合、スクリプト側で「`-Force` を併用してください」エラーで終了する。

## 2. 対話モード（`$ARGUMENTS` が空）

### Step 1: 削除対象の確認

事前に `sync-mappings.ps1 -Action list` で現在のマッピング状況を取得・表示してから、AskUserQuestion で削除対象を選択する。

```text
AskUserQuestion({
  questions: [{
    question: "どのマッピングを削除しますか？",
    header: "削除対象",
    options: [
      {
        label: "カレントディレクトリの project マッピング",
        description: "現在のディレクトリ <repo_root> の project マッピングを削除します。"
      },
      {
        label: "global マッピング",
        description: "~/.claude/ 用の global マッピングを削除します。"
      },
      {
        label: "キャンセル",
        description: "何もせず終了します。"
      }
    ],
    multiSelect: false
  }]
})
```

> **note**: Other（Type something）で他の project パス（カレントディレクトリ以外）を絶対パスで入力することも可能。

### Step 2: 削除確認（誤削除防止）

Step 1 で対象を選択した後、AskUserQuestion で最終確認:

```text
AskUserQuestion({
  questions: [{
    question: "本当に <対象> マッピングを削除しますか？削除すると元に戻せません（再設定が必要）。",
    header: "削除最終確認",
    options: [
      {
        label: "削除する",
        description: "削除を実行します。"
      },
      {
        label: "キャンセル",
        description: "何もせず終了します。"
      }
    ],
    multiSelect: false
  }]
})
```

### Step 3: スクリプト実行

「削除する」が選ばれた場合のみ `sync-mappings.ps1 -Action delete -Scope <scope> [-ProjectPath <path>] -Force` を実行する。

実行後、`-Action list` で更新後の状態を表示してユーザに完了報告。

## 関連

- マッピング設定ファイル: `~/.claude/.local/plugins/maintenance/sync-mappings.json`
- マッピング一覧: `/sync-map-list`
- マッピング設定/更新: `/sync-map-set`
- スキル本体: `sync-settings`
