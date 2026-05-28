---
description: maintenance sync-settings のマッピング設定/更新
argument-hint: "[--scope ...] [--repo URL] [--branch B] [--targets CSV]"
---

`maintenance` プラグインの `sync-settings` スキルが利用するマッピング設定ファイル `~/.claude/.local/plugins/maintenance/sync-mappings.json`（グローバル配下）に、カレントディレクトリの project マッピング（または `--scope global` 指定で global マッピング）を **設定/更新** する。

`$ARGUMENTS` の有無により **2 つの動作モード** を切り替える。

## 1. 非対話モード（`$ARGUMENTS` が非空）

引数を解析し、`${CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync-mappings.sh -Action set` を実行する。

| 引数 | 動作 |
|------|------|
| `--scope <global\|project>` | 対象スコープ（既定は project = カレントディレクトリ） |
| `--repo <url>` | Git リモートリポジトリ URL（必須）|
| `--branch <branch>` | Git ブランチ名（既定 main） |
| `--targets <csv>` | 同期対象のカンマ区切り CSV（既定はスコープ別の標準セット） |
| `--project-path <path>` | project スコープ時の絶対パス（既定はカレントディレクトリのリポジトリルート） |

実行例:

`$ARGUMENTS` の文字列を直接 sync-mappings.sh に展開するのは引数インジェクションの
余地が残るため、**個別フラグを明示的にパースして名前付き引数で渡す**こと。

```bash
bash "$CLAUDE_PLUGIN_ROOT/skills/sync-settings/references/scripts/sync/sync-mappings.sh" "${args[@]}"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
& chcp.com 65001 | Out-Null; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8;

$argText = '$ARGUMENTS'
$params  = @{ Action = 'set' }

if ($argText -match '--scope\s+(global|project)\b')                       { $params.Scope       = $matches[1] }
if ($argText -match '--repo\s+"([^"]+)"|--repo\s+(\S+)')                  { $params.Repo        = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }
if ($argText -match '--branch\s+([A-Za-z0-9._/\-]+)')                     { $params.Branch      = $matches[1] }
if ($argText -match '--targets\s+"([^"]+)"|--targets\s+(\S+)')            { $params.Targets     = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }
if ($argText -match '--project-path\s+"([^"]+)"|--project-path\s+(\S+)')  { $params.ProjectPath = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }

pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync-mappings.ps1" @params
```

</details>

## 2. 対話モード（`$ARGUMENTS` が空）

**既定スコープ = project**（カレントディレクトリ）。global を設定する場合は `--scope global` を引数で明示するか、Step 1 完了後の追加質問で切替可能（実装は AskUserQuestion 経由）。

### Step 1: 設定読み込み

事前に `sync-mappings.sh -Action get -Scope project` を実行し、カレントディレクトリの **現在のマッピング** を取得する（存在しない場合は新規作成）。

### Step 2: AskUserQuestion 3 質問同時発火

3 質問を **同時** に発火する。各質問の構築ルールは Phase 2 `/cleanup-config` と同じ:

| ルール | 内容 |
|-------|------|
| 1 つ目の選択肢 | 現在値（既存設定あり）または 推奨/既定値（新規）|
| 1 つ目の label 末尾 | `（現在の設定）` または `（推奨）` / `（既定）` |
| 残りの選択肢 | 推奨値から現在値を除いたもの |
| Other | AskUserQuestion 仕様で自動付与（自由入力対応）|

#### Question 1: remote_repo（Git リポジトリ URL）

```text
{
  question: "remote_repo（Git リポジトリ URL）を選択してください。Other を選ぶと任意の URL を入力できます（https / http / git / ssh / git@host: のいずれかのプロトコル）。",
  header: "remote_repo",
  options: [
    // 既存設定がある場合:
    { label: "<現在の URL>（現在の設定）", description: "現在のマッピング URL。維持する場合は本選択肢を選択。" },
    { label: "カスタム URL を Other で入力", description: "Other（Type something）で新しい URL を入力してください。" }
    // 新規（既存設定なし）の場合:
    // 既存値がないため Other 入力前提。options は「カスタム URL を Other で入力」「サンプル: https://github.com/<user>/claude-settings」「キャンセル」等で構成
  ],
  multiSelect: false
}
```

> **note**: repo URL は無限の選択肢を持つため、現実的には **Other 自由入力が主たる入力経路**。options の他選択肢はガイダンス目的。

#### Question 2: remote_branch（Git ブランチ名）

```text
{
  question: "remote_branch（Git ブランチ名）を選択してください。Other を選ぶと任意のブランチ名を入力できます（他に release / staging 等が頻用されます）。",
  header: "remote_branch",
  options: [
    // 既存設定がある場合は現在値を 1 つ目に置く。例（現在値 = main）:
    { label: "main（現在の設定）",  description: "現在のブランチ。維持する場合は本選択肢を選択。" },
    { label: "master",              description: "古い既定ブランチ名。" },
    { label: "develop",             description: "開発ブランチを利用する場合。" }
    // 新規の場合は `main（推奨）` / `master` / `develop` の 3 つ
  ],
  multiSelect: false
}
```

#### Question 3: targets（同期対象リスト）

```text
{
  question: "targets（同期対象リスト）を選択してください。Other を選ぶとカンマ区切りで任意のパスを入力できます。",
  header: "targets",
  options: [
    // 既存設定がある場合は現在値の概要を 1 つ目に置く:
    { label: "<targets を維持>（現在の設定）", description: "現在の targets リストを保持。維持する場合は本選択肢を選択。" },
    { label: "既定の project セット",         description: ".claude/settings.json, .claude/skills, .claude/rules, .claude/agents, .claude/hooks, .claude/CLAUDE.md（project スコープ既定）" },
    { label: "最小セット（settings.json のみ）", description: ".claude/settings.json のみを同期" }
    // 新規（既存設定なし）の場合は `既定の project セット（推奨）` を 1 つ目
  ],
  multiSelect: false
}
```

> **note**: global スコープでの targets 推奨セットは `settings.json, skills, rules, agents, hooks, CLAUDE.md`（`.claude/` プレフィックスなし）。

### Step 3: 変更検出 + バリデーション

3 つの選択結果と現在値を比較:

| 状況 | 動作 |
|-----|------|
| 全項目が現在値と同じ | 変更なし、`-Show` で現在の設定を表示して終了 |
| 1 項目以上変更あり | `-Action set` を引数付きで実行 |

Other 自由入力時のバリデーション:

- `remote_repo`: URL 形式（`^(https?|git|ssh)://|^git@[A-Za-z0-9._\-]+:`）を満たさない / `-` で始まる → 再入力誘導
- `remote_branch`: 許可文字（`^[A-Za-z0-9._/\-]+$`）を満たさない → 再入力誘導
- `targets`: カンマ区切りで Trim 後の各要素が空でなければ受理

### Step 4: スクリプト実行

```bash
bash "...sync-mappings.sh" -Action set -Scope <scope> [-ProjectPath <path>] -Repo "<repo>" -Branch "<branch>" -Targets "<csv>"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
pwsh -NoProfile -File "...sync-mappings.ps1" -Action set -Scope <scope> [-ProjectPath <path>] -Repo "<repo>" -Branch "<branch>" -Targets "<csv>"
```

</details>

実行後、保存された設定を表示してユーザに完了報告（変更前→変更後の差分を提示）。

## 関連

- マッピング設定ファイル: `~/.claude/.local/plugins/maintenance/sync-mappings.json`
- マッピング一覧: `/sync-map-list`
- マッピング削除: `/sync-map-delete`
- スキル本体: `sync-settings`
