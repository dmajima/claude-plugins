# 実行手順詳細

`cleanup-workspace` スキルの実行詳細手順。SKILL.md から参照される。

## 1. 対象収集

### 1.1 ルート列挙

`--scope` 引数に応じて以下を収集する。

| スコープ | パス | 取得方法 |
|---------|-----|---------|
| `global` | `$env:USERPROFILE\.claude\.local\work` | `Test-Path` で存在確認 |
| `project` | `<repo_root>/.claude/.local/work` | `git rev-parse --show-toplevel` で repo_root 取得（失敗時は現在のディレクトリ） |
| `both`（既定） | 上記両方 | 同一パスは重複除去 |

### 1.2 セッションフォルダ列挙

各ルート直下のディレクトリを `Get-ChildItem -Directory` で列挙し、以下を満たすもののみ候補に追加する。

| 条件 | 内容 |
|-----|------|
| 名前形式 | 正規表現 `^\d{8}_\d{2}_[A-Za-z0-9._\-]+$` に一致 |
| リンク種別 | `LinkType` が `SymbolicLink` でない |

不一致のディレクトリは安全のため無視（Verbose ログには出力）。

### 1.3 最終更新日時の取得

セッションフォルダ自身の mtime ではなく、配下の全ファイルを再帰走査して最も新しい mtime を採用する。これにより `workspace/` 内で更新があったセッションを「進行中」として正しく検出できる。

```powershell
$lastWrite = $session.LastWriteTimeUtc
Get-ChildItem -Path $session.FullName -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.LastWriteTimeUtc -gt $lastWrite) { $lastWrite = $_.LastWriteTimeUtc }
}
```

## 2. 古さ判定 + keep-recent 適用

### 2.1 古さ判定

| 条件 | 動作 |
|-----|------|
| `lastWrite < UtcNow - Days` | 候補に追加 |
| `lastWrite >= UtcNow - Days` | スキップ |

### 2.2 進行中セッション保護

`progress.md` の mtime が UtcNow から 5 分以内なら、古さ判定を満たしても候補から除外する。

```powershell
$progressPath = Join-Path $session.FullName 'progress.md'
if (Test-Path $progressPath) {
    $progMtime = (Get-Item $progressPath).LastWriteTimeUtc
    if ($progMtime -gt $nowUtc.AddMinutes(-5)) { continue }
}
```

### 2.3 keep-recent 適用

`--keep-recent N` が指定された場合、スコープごとに新しい順で N 件を候補から除外する。

```powershell
$filtered = @()
foreach ($scope in ($candidates | Group-Object Scope)) {
    $sorted = $scope.Group | Sort-Object LastWrite -Descending
    $filtered += $sorted | Select-Object -Skip $KeepRecent
}
$candidates = $filtered
```

## 3. AskUserQuestion 構造（対話モード）

候補一覧と合計容量を表示した後、以下の構造で確認する。

```text
AskUserQuestion({
  questions: [{
    question: "{N} 件のセッションフォルダ ({合計容量} MB) を削除しますか？",
    header: "削除確認",
    options: [
      {
        label: "削除する",
        description: "{N} 件のセッションフォルダを完全削除します。元に戻せません。"
      },
      {
        label: "ドライランで終了",
        description: "削除候補のみ表示して終了します。実削除は行いません。"
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

| 選択結果 | 動作 |
|---------|------|
| `削除する` | スクリプトを `--yes` 付きで再実行（実削除） |
| `ドライランで終了` | サマリのみ表示して終了 |
| `キャンセル` | 何もせず終了（ユーザに「中止しました」と報告） |

## 4. 削除実行

### 4.1 削除コマンド

```powershell
foreach ($c in $candidates) {
    try {
        Remove-Item -Path $c.Path -Recurse -Force -ErrorAction Stop
        $deleted++
        $freedBytes += $c.SizeBytes
    } catch {
        $failed += [PSCustomObject]@{ Path=$c.Path; Error=$_.Exception.Message }
    }
}
```

### 4.2 失敗時の挙動

| 失敗種別 | 対応 |
|---------|------|
| 権限不足 | 当該フォルダのみスキップ、他は続行。サマリの失敗一覧に記録 |
| ファイルロック | 同上 |
| パスが存在しない（並行削除等） | スキップして警告ログ |

## 5. `--include-tmp` の追加クリーンアップ

`--include-tmp` 指定時のみ、削除されなかったセッション（=古さ条件を満たさない）の `workspace/tmp/` 配下を別途掃除する。

```powershell
foreach ($root in $roots) {
    Get-ChildItem -Path $root.Path -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $SESSION_REGEX -and $_.LinkType -ne 'SymbolicLink' } |
        ForEach-Object {
            $tmpPath = Join-Path $_.FullName 'workspace\tmp'
            if (Test-Path $tmpPath) {
                Get-ChildItem -Path $tmpPath -Recurse -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
}
```

`workspace/tmp/` 自体は残し、配下のファイルのみ削除する。

## 6. サマリ出力

```text
===== クリーンアップ結果 =====
スコープ:           global / project / both
閾値日数:           30 日
削除候補:           N 件 (XXX MB)
削除完了:           N 件
削除失敗:           N 件
解放容量:           XXX MB
保護されたセッション: N 件
  - keep-recent:   N 件
  - 進行中:        N 件

失敗一覧:
  [SCOPE] <path>  -- <error message>
```

## 7. エラーハンドリング

| エラー | 対応 |
|-------|------|
| ルートディレクトリ不在 | スキップ（警告のみ） |
| バリデーション失敗 | 当該フォルダをスキップ、他は続行 |
| 削除失敗（権限・ロック等） | 当該フォルダをスキップ、サマリに記録 |
| `git rev-parse` 失敗（リポジトリ外） | プロジェクトスコープは現在のディレクトリで代替判定 |
| すべてのスコープでルート不在 | 「対象なし」と報告して終了（エラーではない） |

## 8. 引数の組み合わせ規則

| 組み合わせ | 動作 |
|----------|------|
| `--dry-run` + `--yes` | `--dry-run` 優先（実削除なし、警告ログ出力） |
| `--scope global` + `--keep-recent 5` | global スコープのみ対象、新しい順 5 件保護 |
| `--include-tmp` 単独 | 通常のセッション削除 + 全セッションの tmp 掃除 |
| `--include-tmp` + `--dry-run` | tmp 掃除の対象もドライラン表示 |
