# 実行手順詳細

`sync-settings` スキルの実行詳細手順。SKILL.md から参照される。

## 1. 設定解決

### 1.1 設定ファイルパス

**SSOT（v0.2.0+）**: `~/.claude/.local/plugins/maintenance/sync-mappings.json`

- global / projects[`<absolute_path>`] のスコープ別マッピングを保持
- `/sync-map-set` / `/sync-map-list` / `/sync-map-delete` で CRUD
- 各エントリは `remote_repo` / `remote_branch` / `targets` / `last_sync_at` を持つ

**互換ストア（v0.3.0 で廃止予定 / ADR-PU-011）**:
`~/.claude/.local/plugins/maintenance/sync-config.json`

### 1.2 設定ファイル構造

```json
{
  "version": 1,
  "last_repo": "https://github.com/myaccount/claude-settings",
  "last_branch": "main",
  "last_targets": ["settings.json", "skills", "rules", "agents", "hooks", "CLAUDE.md"],
  "last_strategy": "overwrite",
  "last_sync_at": "2026-05-18T10:23:45Z",
  "history": [
    {
      "sync_at": "2026-05-18T10:23:45Z",
      "repo": "https://github.com/myaccount/claude-settings",
      "branch": "main",
      "strategy": "overwrite",
      "commit": "<abbreviated sha>"
    }
  ]
}
```

### 1.3 解決優先順位

| 優先 | 取得元 |
|-----|-------|
| 1（最優先） | 引数オーバーライド（`--repo` / `--branch` / `--targets` / `--strategy`） |
| 2 | マッピングストア `sync-mappings.json`（SSOT、`--scope` 指定時） |
| 3 | 互換ストア `sync-config.json` の `last_*` フィールド（v0.3.0 で削除予定） |
| 4 | 既定値（`branch="main"` / `targets=["settings.json","skills","rules","agents","hooks","CLAUDE.md"]` / `strategy="overwrite"`） |

`repo` が不足している場合は対話で `AskUserQuestion` を経ずテキスト対話で取得（自由入力のため）。非対話モードでは `--repo` 不足はエラーで終了。

> **v0.3.0 移行ガイド（ADR-PU-011）**: `sync-config.json` 経由の暗黙取得は v0.3.0 で廃止される。
> 既存ユーザは `/sync-map-set` で マッピングを明示設定することを推奨。新規ユーザは最初から
> マッピング設定での運用を行うこと。

## 2. リポジトリ取得と差分検出

### 2.1 クローン先

```
~/.claude/.local/plugins/maintenance/repo/
```

このディレクトリは sync-settings 専用。既存内容は毎回 reset され、ローカル変更の混入を防ぐ。

### 2.2 取得コマンド

```bash
git clone --depth 1 --branch $Branch $Repo $repoDir
    Push-Location $repoDir
    git fetch --depth 1 origin $Branch
    git reset --hard "origin/$Branch"
    git clean -fdx
    Pop-Location
```

<details><summary>PowerShell フォールバック</summary>

```powershell
$repoDir = Join-Path $env:USERPROFILE '.claude\.local\plugins\maintenance\repo'

if (-not (Test-Path $repoDir)) {
    git clone --depth 1 --branch $Branch $Repo $repoDir
} else {
    Push-Location $repoDir
    git fetch --depth 1 origin $Branch
    git reset --hard "origin/$Branch"
    git clean -fdx
    Pop-Location
}
```

</details>

### 2.3 同期対象の検出

`--targets` で指定された各エントリについて、クローン先で実在するかを確認する。優先順位:

| 優先 | 検索パス |
|-----|---------|
| 1 | `<clone_root>/<target>` |
| 2 | `<clone_root>/claude/<target>` |

両方に存在する場合は 1 を優先（リポジトリ作者が想定した構造）。

### 2.4 差分検出

各対象について以下のロジックで差分を判定:

| 対象種別 | 比較方法 |
|---------|---------|
| ファイル（`settings.json`、`CLAUDE.md` 等） | SHA256 ハッシュ比較 |
| ディレクトリ（`skills/`、`rules/` 等） | 再帰的に各ファイルを比較。ファイル一覧の差分と各ファイルの内容差分 |

| 差分種別 | 表示プレフィックス |
|---------|-------------------|
| 新規（リモートのみ） | `[ADD]` |
| 削除（ローカルのみ） | `[DEL]`（`--prune` 指定時のみ適用） |
| 変更（差分あり） | `[MOD]` |
| 一致 | `[OK]`（表示省略） |

## 3. バックアップ取得

### 3.1 バックアップパス

```
~/.claude/.local/plugins/maintenance/backup/{YYYYMMDD_HHmmss}/
```

### 3.2 取得対象

同期対象として実在する `~/.claude/` 配下のファイル・ディレクトリのみコピーする（同期しないものはバックアップしない）。

### 3.3 取得コマンド

```bash
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

        Copy-Item -Recurse -Force -LiteralPath $src -Destination $dst
```

<details><summary>PowerShell フォールバック</summary>

```powershell
$backupRoot = Join-Path $env:USERPROFILE '.claude\.local\plugins\maintenance\backup'
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $backupRoot $ts
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

foreach ($target in $targets) {
    $src = Join-Path $env:USERPROFILE ".claude\$target"
    if (Test-Path $src) {
        $dst = Join-Path $backupDir $target
        Copy-Item -Recurse -Force -LiteralPath $src -Destination $dst
    }
}
```

</details>

### 3.4 認証情報の除外

バックアップ取得時も以下は除外:

| 除外パス | 理由 |
|---------|------|
| `~/.claude/credentials.json` | 認証情報 |
| `~/.claude/.env*` | 環境変数 |
| `~/.claude/.local/` | ローカルデータ領域（バックアップ自身を含むため再帰回避） |
| `~/.claude/.git/` | Git メタデータ |

## 4. 戦略別の同期適用

### 4.1 overwrite（既定）

| 状況 | 動作 |
|-----|------|
| リモートのみに存在 | ローカルに新規作成 |
| 両方に存在・内容差分 | リモートで上書き |
| ローカルのみに存在 | `--prune` 指定時のみ削除。既定は保持 |
| 両方に存在・一致 | 何もしない |

### 4.2 merge

| 状況 | 動作 |
|-----|------|
| `settings.json`（ファイル） | JSON マージ。リモートのキーで既存値を上書き、リモートにないキーは保持 |
| ディレクトリ（`skills/` 等） | ファイル単位で結合。同名ファイルはリモートで上書き、ローカルのみのファイルは保持 |
| ローカルのみに存在 | 保持 |

JSON マージは `extension-toolkit:credentials-manager` 等で実装されている深いマージ（配列は連結ではなく置換）と同方針。

### 4.3 skip

| 状況 | 動作 |
|-----|------|
| 両方に存在 | スキップ（既存保持） |
| リモートのみ | 新規作成 |
| ローカルのみ | 保持 |

## 5. AskUserQuestion 構造（対話モード）

```text
AskUserQuestion({
  questions: [{
    question: "{N} 件のファイル変更を ~/.claude/ に適用しますか？（戦略: {strategy}）",
    header: "同期確認",
    options: [
      {
        label: "同期する",
        description: "バックアップを取得した後、{strategy} 戦略で同期を実行します。"
      },
      {
        label: "ドライランで終了",
        description: "差分のみ表示して終了します。実適用は行いません。"
      },
      {
        label: "戦略を変更して再表示",
        description: "戦略（overwrite / merge / skip）を変更して差分を再計算します。"
      },
      {
        label: "キャンセル",
        description: "操作を中止します。"
      }
    ],
    multiSelect: false
  }]
})
```

「戦略を変更して再表示」を選択した場合は、戦略選択用の AskUserQuestion を続けて表示する。

## 6. 設定状態の永続化

成功時、`sync-config.json` を以下のように更新:

```json
{
  "version": 1,
  "last_repo": "<repo>",
  "last_branch": "<branch>",
  "last_targets": ["..."],
  "last_strategy": "<strategy>",
  "last_sync_at": "<ISO8601>",
  "history": [<以前の履歴> + 今回のエントリ]
}
```

`history[]` は新しい順 10 件まで保持し、それ以降は切り詰める。

## 7. サマリ出力

```text
===== 同期結果 =====
Repo:              <repo>
Branch:            <branch>
Commit:            <abbreviated sha>
戦略:              <strategy>
バックアップ:      <backup dir>

適用件数:
  [ADD] N 件
  [MOD] N 件
  [DEL] N 件（--prune 指定時のみ）
失敗:              N 件
```

## 8. エラーハンドリング

| エラー | 対応 |
|-------|------|
| Git CLI 不在 | エラーで終了。インストール手順を案内 |
| `clone` 失敗（認証等） | エラーで終了。`credentials-manager` 連携を案内 |
| ブランチ不在 | エラーで終了、利用可能ブランチ一覧を提示 |
| 同期元構造異常（target 不在） | 当該 target をスキップして警告。他は続行 |
| バックアップ失敗 | エラーで終了。同期は実行しない（安全側） |
| 同期適用中のファイルロック等 | 当該ファイルをスキップ、サマリに記録 |
| `--prune` 指定 + 削除対象多数（10 件超） | 追加の AskUserQuestion で再確認 |

## 9. 引数の組み合わせ規則

| 組み合わせ | 動作 |
|----------|------|
| `--dry-run` + `--yes` | `--dry-run` 優先（実適用なし、警告ログ） |
| `--no-backup` + `--yes` | バックアップなしで即同期（強い警告ログを出力） |
| `--strategy merge` + `--prune` | merge 戦略で `--prune` は無効（warning） |
| `--repo` 不指定 + 設定ファイル不在 | 対話モードでは URL を収集、非対話モードではエラー |
