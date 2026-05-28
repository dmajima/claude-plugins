---
description: maintenance sync-settings のマッピングに従って pull 同期
argument-hint: "[--scope ...] [--strategy ...] [--dry-run] [--yes]"
---

`maintenance` プラグインの `sync-settings` スキルが利用するマッピング設定 `sync-mappings.json` に従って、リモート Git リポジトリから `~/.claude/` または `<project>/.claude/` 配下を **pull 同期** するコマンド。

**前提**: 事前に `/sync-map-set` で対象スコープのマッピングを設定しておく必要がある。

`$ARGUMENTS` の有無により **2 つの動作モード** を切り替える。

## 1. 非対話モード（`$ARGUMENTS` が非空 + `--scope` 明示）

引数を解析し、`${CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync.sh -Mapping <scope>` を実行する。

| 引数 | 動作 |
|------|------|
| `--scope <global\|project>` | 対象スコープ。`sync-mappings.json` から該当マッピングを取得して sync.sh に渡す |
| `--strategy <overwrite\|merge\|skip\|interactive>` | 同期戦略（既定 overwrite）|
| `--dry-run` | ドライラン（差分プレビューのみ・実適用なし） |
| `--no-backup` | バックアップなし（既定はバックアップ取得） |
| `--prune` | overwrite 戦略時、リモートに存在しないローカルファイルを削除 |
| `--yes` | AskUserQuestion 確認をスキップして実適用 |

実行例（overwrite / merge / skip 戦略の場合）:

`$ARGUMENTS` の文字列を直接 sync.sh に展開するのは引数インジェクションの
余地が残るため、**個別フラグを明示的にパースして名前付き引数で渡す**こと。

```bash
# --- 引数を個別に抽出（$ARGUMENTS 直展開は禁止） ---

# interactive は別フローへ分岐（下記 Step 2-B 参照）
    # interactive 戦略は Claude 主導のループ実装（下記参照）
    bash "$CLAUDE_PLUGIN_ROOT/skills/sync-settings/references/scripts/sync/sync.sh" "${args[@]}"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
& chcp.com 65001 | Out-Null; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8;

# --- 引数を個別に抽出（$ARGUMENTS 直展開は禁止） ---
$argText = '$ARGUMENTS'
$params  = @{}

if ($argText -match '--scope\s+(global|project)\b')                                   { $params.Mapping     = $matches[1] }
if ($argText -match '--strategy\s+(overwrite|merge|skip|interactive)\b')              { $params.Strategy    = $matches[1] }
if ($argText -match '--project-path\s+"([^"]+)"|--project-path\s+(\S+)')              { $params.ProjectPath = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }
if ($argText -match '\B--dry-run\b')                                                  { $params.DryRun      = $true }
if ($argText -match '\B--no-backup\b')                                                { $params.NoBackup    = $true }
if ($argText -match '\B--prune\b')                                                    { $params.Prune       = $true }
if ($argText -match '\B--yes\b')                                                      { $params.Yes         = $true }

if (-not $params.ContainsKey('Mapping')) {
    Write-Error "--scope <global|project> が必須です（対話モードでの起動は別フロー）。"
    exit 1
}

# interactive は別フローへ分岐（下記 Step 2-B 参照）
if ($params.Strategy -eq 'interactive') {
    # interactive 戦略は Claude 主導のループ実装（下記参照）
} else {
    pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync.ps1" @params
}
```

</details>

`--strategy interactive` が指定された場合は、下記の interactive フローへ分岐する。

## 2. 対話モード（`$ARGUMENTS` が空）

AskUserQuestion 1 回で 2 質問同時発火し、scope / strategy を確認する。

### Step 1: AskUserQuestion 2 質問同時発火

```text
AskUserQuestion({
  questions: [
    {
      question: "対象スコープを選択してください。",
      header: "scope",
      options: [
        { label: "project（カレントディレクトリ）", description: "<repo_root>/.claude/ のマッピングを pull 同期。" },
        { label: "global（~/.claude）",              description: "ユーザのグローバル設定を pull 同期。" }
      ],
      multiSelect: false
    },
    {
      question: "同期戦略を選択してください。Other を選ぶと任意の戦略名を入力できます。",
      header: "strategy",
      options: [
        { label: "interactive（推奨）",  description: "差分 1 件ごとに AskUserQuestion で「上書き/保持/スキップ」を確認します。" },
        { label: "overwrite",            description: "リモートで一括上書き。リモートを正典として扱う場合。" },
        { label: "merge",                description: "settings.json は JSON マージ、ディレクトリはファイル単位結合。ローカル個別設定を温存。" }
      ],
      multiSelect: false
    }
  ]
})
```

> **note**: `skip` 戦略は使用頻度が低いため Other での選択に委ねる。

### Step 2: 戦略別フロー

#### 2-A. strategy = overwrite / merge / skip（非対話 sync.sh 連動）

選択値を引数として sync.sh を起動:

```bash
bash "...sync.sh" -Mapping <scope> -Strategy <strategy>
```

<details><summary>PowerShell フォールバック</summary>

```powershell
pwsh -NoProfile -File "...sync.ps1" -Mapping <scope> -Strategy <strategy>
```

</details>

#### 2-B. strategy = interactive（差分ごとの対話）

interactive 戦略は **Claude 主導のループ実装**:

##### Step 2-B-1: 差分一覧の取得（sync.sh 経由）

```bash
bash "...sync.sh" -Mapping <scope> -EmitDiffJson "$tmpJson"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
$tmpJson = ".claude/.local/work/<session>/workspace/sync-diff.json"
pwsh -NoProfile -File "...sync.ps1" -Mapping <scope> -EmitDiffJson "$tmpJson"
```

</details>

`-EmitDiffJson` 指定時、sync.sh は差分検出後に JSON ファイルへ書き出して exit 0。実適用はしない。

##### Step 2-B-2: JSON 解析 + 件数による分岐

| 差分件数 | 動作 |
|---------|------|
| 0 件 | 「同期不要」と報告して終了 |
| 1〜5 件 | 各差分について AskUserQuestion 個別発火（下記 2-B-3） |
| 6 件以上 | 一括選択 AskUserQuestion 発火（下記 2-B-4）|

##### Step 2-B-3: 差分 1 件ごとの AskUserQuestion（1〜5 件時）

各差分エントリ（`Op` / `Local` / `Remote` / `RelPath`）について 1 件ずつ確認:

```text
AskUserQuestion({
  questions: [{
    question: "差分 [<Op>] <RelPath>（残り <remaining> 件）をどう扱いますか？",
    header: "差分解決",
    options: [
      { label: "上書き（リモートで上書き）", description: "リモートのファイル内容で local を上書き。" },
      { label: "保持（ローカルを保持）",     description: "リモート側を無視してローカル側を維持。" },
      { label: "スキップ（この差分を無視）", description: "今回は何もせず、次の差分に進む（保持と同じ効果だが意図を区別）。" }
    ],
    multiSelect: false
  }]
})
```

##### Step 2-B-4: 一括選択 AskUserQuestion（6 件以上時）

```text
AskUserQuestion({
  questions: [{
    question: "差分が <N> 件あります。一括処理するか個別判断するか選択してください。",
    header: "差分一括処理",
    options: [
      { label: "全件 overwrite", description: "<N> 件すべてをリモートで上書きする（バックアップは取得される）。" },
      { label: "全件 skip",      description: "今回は何も適用しない（dry-run と同等で終了）。" },
      { label: "個別判断",       description: "1 件ずつ AskUserQuestion で確認する（5 件超のため UX 負荷あり）。" },
      { label: "キャンセル",     description: "操作を中止する。" }
    ],
    multiSelect: false
  }]
})
```

##### Step 2-B-5: 決定に従った適用（Claude 直接実行）

各差分の決定に応じて Claude が直接 Copy-Item / Remove-Item を実行:

| 決定 | Op = ADD/MOD | Op = DEL |
|-----|------------|---------|
| 上書き | `Copy-Item -LiteralPath $Remote -Destination $Local -Force`（親ディレクトリ自動作成）| `Remove-Item -LiteralPath $Local -Force` |
| 保持 / スキップ | 何もしない | 何もしない |

**バックアップ取得**: 適用前に Claude が `~/.claude/.local/plugins/maintenance/backup/<YYYYMMDD_HHmmss>/` に対象ファイルをコピー（既存 sync.sh のバックアップロジックと同等）。`--no-backup` 指定時はスキップ。

##### Step 2-B-6: 完了報告

適用件数 / 保持件数 / スキップ件数 / 失敗件数を集計してユーザに提示。`sync-mappings.json` の `last_sync_at` も更新可能（任意）。

## エラー処理

| エラー | 対応 |
|-------|------|
| マッピング不在 | sync.sh がエラーで終了。「/sync-map-set で設定してください」と案内 |
| 差分件数 0 | 「同期不要」と報告して終了 |
| Copy-Item 失敗（権限・ロック） | 当該ファイルをスキップして次へ。失敗一覧をサマリに含める |
| AskUserQuestion 途中キャンセル | 残りの差分を保留として終了（既適用分は維持） |

## 関連

- マッピング設定/更新: `/sync-map-set`
- マッピング一覧: `/sync-map-list`
- マッピング削除: `/sync-map-delete`
- スキル本体: `sync-settings`
- push 同期: `/sync-push`（新ブランチ + PR 作成。sync-push.sh）
