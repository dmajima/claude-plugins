---
description: maintenance sync-settings のマッピングに従って push 同期（別ブランチ + PR 作成）
argument-hint: "[--scope ...] [--no-pr] [--dry-run] [--yes]"
---

`maintenance` プラグインの `sync-settings` スキルが利用するマッピング設定 `sync-mappings.json` に従って、ローカルの `~/.claude/` または `<project>/.claude/` 配下を **push 方向** でリモート Git リポジトリへ送信するコマンド。

**フロー設計**: 規定ブランチに直接 push せず、**新ブランチを作成してそこに push** し、規定ブランチに復帰してから **PR を自動作成** する。レビューと履歴管理を可能にするための PR ベースワークフロー。

**前提**:
- 事前に `/sync-map-set` でマッピングを設定
- リモートへの push 権限
- PR 作成には GitHub CLI（`gh`）が利用可能で `gh auth login` 済みであること

**安全装置**:
- 認証情報（`credentials.json` / `.env` / `*.pem` 等）は常に除外
- Git メタデータ（`.git/`）も除外
- 規定ブランチに直接 push しない（必ず新ブランチを経由）
- push 完了後、規定ブランチに自動復帰（スキル起動前と同様の状態に戻る）
- PR 作成失敗時はユーザに通知 + 手動作成案内
- `--dry-run` でプレビュー可能
- 実 push には `--yes` または対話モードでの AskUserQuestion 確認が必要

## フロー概要

1. **マッピング解決**: `sync-mappings.json` から remote_repo / remote_branch / targets を取得
2. **clone 領域準備**: `~/.claude/.local/plugins/maintenance/repo/` を fetch + reset --hard
3. **ローカル → repo/ コピー**: targets を除外フィルタ適用しつつコピー
4. **変更検出**: `git status --short`、変更なしなら即終了
5. **新ブランチ作成**: `sync-from-local-<scope>-<YYYYMMDD-HHmmss>`
6. **commit + push**: 新ブランチに変更を commit、`git push -u origin <new-branch>`
7. **規定ブランチに復帰**: `git checkout <remote_branch>`（変更は新ブランチに完全に隔離、ローカル repo/ は規定ブランチの内容に戻る）
8. **PR 作成**: `gh pr create --base <remote_branch> --head <new-branch>`
9. **完了報告**: PR URL + 新ブランチ名をユーザに提示

## 1. 非対話モード（`$ARGUMENTS` が非空）

引数を解析し、`${CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync-push.sh` を実行する。

| 引数 | 動作 |
|------|------|
| `--scope <global\|project>` | 対象スコープ（必須）|
| `--commit-message <msg>` | git commit メッセージ（既定: `sync from local <ISO8601>`） |
| `--branch-prefix <prefix>` | 新ブランチ名のプレフィクス（既定: `sync-from-local`） |
| `--pr-title <title>` | PR タイトル（既定: 自動生成） |
| `--pr-body <body>` | PR 本文（既定: 自動生成、scope/targets/commit を含む）|
| `--no-pr` | PR 作成をスキップ（push のみ実施）|
| `--project-path <path>` | project スコープ時の対象パス |
| `--dry-run` | git status プレビューのみ、commit/push/PR なし |
| `--yes` | AskUserQuestion 確認をスキップして実 push + PR 作成 |

実行例:

`$ARGUMENTS` の文字列を直接 sync-push.sh に展開するのは引数インジェクションの
余地が残るため、**個別フラグを明示的にパースして名前付き引数で渡す**こと。

```bash
# --- 引数を個別に抽出（$ARGUMENTS 直展開は禁止） ---

bash "$CLAUDE_PLUGIN_ROOT/skills/sync-settings/references/scripts/sync/sync-push.sh" "${args[@]}"
```

<details><summary>PowerShell フォールバック</summary>

```powershell
& chcp.com 65001 | Out-Null; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8;

# --- 引数を個別に抽出（$ARGUMENTS 直展開は禁止） ---
$argText = '$ARGUMENTS'
$params  = @{}

if ($argText -match '--scope\s+(global|project)\b')                                                            { $params.Mapping       = $matches[1] }
if ($argText -match '--commit-message\s+"([^"]+)"|--commit-message\s+(\S+)')                                   { $params.CommitMessage = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }
if ($argText -match '--branch-prefix\s+([A-Za-z0-9._\-]+)')                                                    { $params.BranchPrefix  = $matches[1] }
if ($argText -match '--pr-title\s+"([^"]+)"|--pr-title\s+(\S+)')                                               { $params.PrTitle       = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }
if ($argText -match '--pr-body\s+"([^"]+)"|--pr-body\s+(\S+)')                                                 { $params.PrBody        = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }
if ($argText -match '--project-path\s+"([^"]+)"|--project-path\s+(\S+)')                                       { $params.ProjectPath   = ($matches[1], $matches[2] -ne '' | Select-Object -First 1) }
if ($argText -match '\B--no-pr\b')                                                                              { $params.NoPr          = $true }
if ($argText -match '\B--dry-run\b')                                                                            { $params.DryRun        = $true }
if ($argText -match '\B--yes\b')                                                                                { $params.Yes           = $true }

if (-not $params.ContainsKey('Mapping')) {
    Write-Error "--scope <global|project> が必須です（対話モードでの起動は別フロー）。"
    exit 1
}

pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/skills/sync-settings/references/scripts/sync/sync-push.ps1" @params
```

</details>

## 2. 対話モード（`$ARGUMENTS` が空）

### Step 1: AskUserQuestion 2 質問同時発火

```text
AskUserQuestion({
  questions: [
    {
      question: "push 対象スコープを選択してください。",
      header: "scope",
      options: [
        { label: "project（カレントディレクトリ）", description: "<repo_root>/.claude/ をマッピングされた repo に push。" },
        { label: "global（~/.claude）",              description: "ユーザのグローバル設定をマッピングされた repo に push。" }
      ],
      multiSelect: false
    },
    {
      question: "commit メッセージを選択してください。Other を選ぶと任意のメッセージを入力できます。",
      header: "commit_message",
      options: [
        { label: "自動生成（sync from local <timestamp>）", description: "ISO8601 タイムスタンプ付きの定型メッセージ。" },
        { label: "skills の更新",                            description: "スキル定義の更新を行った場合の典型メッセージ。" },
        { label: "rules の更新",                             description: "ルールの更新を行った場合の典型メッセージ。" }
      ],
      multiSelect: false
    }
  ]
})
```

### Step 2: dry-run プレビュー

選択された scope で `sync-push.sh -Mapping <scope> -DryRun` を実行し、git status の差分をユーザに表示。

### Step 3: AskUserQuestion 最終確認

```text
AskUserQuestion({
  questions: [{
    question: "上記の差分を新ブランチ '<branch-prefix>-<scope>-<ts>' に push して PR を作成しますか？ベースは {remote_branch}（{remote_repo}）です。",
    header: "push + PR 最終確認",
    options: [
      { label: "push + PR 作成", description: "新ブランチに git commit + push、規定ブランチ復帰、gh pr create を順次実行します。" },
      { label: "push のみ（PR スキップ）", description: "新ブランチに push しますが、PR は作成しません（手動作成）。" },
      { label: "差分を再確認したい", description: "dry-run を再度実行して差分を確認します。" },
      { label: "キャンセル", description: "何もせず終了します。" }
    ],
    multiSelect: false
  }]
})
```

### Step 4: 実行

| 選択 | 実行コマンド |
|------|------------|
| push + PR 作成 | `sync-push.sh -Mapping <scope> -CommitMessage <msg> -Yes` |
| push のみ（PR スキップ）| `sync-push.sh -Mapping <scope> -CommitMessage <msg> -NoPr -Yes` |
| 再確認 | dry-run プレビュー再実行 |
| キャンセル | exit 0、ユーザに「中止しました」通知 |

### Step 5: 完了報告

| 項目 | 内容 |
|-----|------|
| Repo | <remote_repo> |
| Base | <remote_branch>（規定ブランチ）|
| Head branch | <new-branch>（自動生成または `--branch-prefix` 指定）|
| Commit | <message> |
| PR | <URL> または「未作成・手動対応が必要」 |

## エラー処理

| エラー | 対応 |
|-------|------|
| マッピング不在 | sync-push.sh がエラー。「/sync-map-set で設定してください」と案内 |
| 変更なし | 「変更なし。push をスキップ」exit 0 |
| Git CLI 不在 | exit 1、インストール案内 |
| 新ブランチ作成失敗 | exit 1、エラーメッセージ |
| git add/commit/push 失敗 | exit 1、新ブランチ削除して規定ブランチに復帰（ベストエフォート） |
| 規定ブランチ復帰失敗 | warning 出力、手動 checkout を案内 |
| gh CLI 不在 / PR 作成失敗 | warning 出力 + 手動 PR 作成案内（base / head / repo を提示）|

## 設計意図

- **規定ブランチに直接 push しない**: 共同作業環境やレビュー前提の運用に対応
- **新ブランチを毎回作成**: 同期の都度履歴を分離、複数同期のコリジョン回避
- **規定ブランチ復帰**: スキル起動前と同様の repo/ 状態に戻すことで、他の操作との干渉を防止
- **PR 自動作成**: 通常のレビュー / マージワークフローに自然に組み込める
- **`--no-pr` オプション**: gh CLI 不在環境や、独自の PR 作成ワークフローを持つ環境のため

## 関連

- pull 同期: `/sync-pull`
- マッピング設定: `/sync-map-set`
- マッピング一覧: `/sync-map-list`
- マッピング削除: `/sync-map-delete`
- 認証情報管理: `credentials-manager` プラグイン
- スキル本体: `sync-settings`
- 外部依存: [GitHub CLI (`gh`)](https://cli.github.com/)（PR 作成時）
