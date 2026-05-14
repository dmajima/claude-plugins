# check_version_bump.ps1 - Stop フック (PowerShell 7+ 版、ADR-026 v2 真因対策)
#
# 目的:
#   Claude のターン終了時、ワーキングツリーに plugins/{name}/ 配下の
#   未コミット変更があり、かつ対応する plugin.json の version が
#   未更新の場合に警告を出す。
#
# 入力:
#   stdin: Claude Code から渡される Stop イベント JSON (本フックは内容不問)
#
# 出力:
#   - 該当変更なし or 全プラグインで version 更新済み: exit 0、無音
#   - version 未更新のプラグインあり: exit 0 + stderr に警告 (fail-open)
#
# 設計:
#   - exit 0 (fail-open)。Claude のターンを止めない
#   - stderr メッセージは Claude Code が次ターンの context として扱う想定
#   - git が利用できない / リポジトリでない環境では何もしない (無音 exit 0)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

try {
    # stdin を読み捨て (ファイルディスクリプタ詰まり防止)
    $null = [Console]::In.ReadToEnd()

    # git 利用不可ならスキップ
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) { exit 0 }

    # リポジトリ外ならスキップ
    $inRepo = (& git rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -ne 0 -or $inRepo -ne 'true') { exit 0 }

    # main ブランチを特定
    $base = ''
    & git rev-parse --verify origin/main 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $base = 'origin/main'
    } else {
        & git rev-parse --verify main 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $base = 'main'
        }
    }

    # 未コミット変更 (staged + unstaged + untracked) 一覧
    $statusOutput = & git status --porcelain 2>$null
    $uncommitted = @()
    foreach ($line in @($statusOutput)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        # 先頭 3 文字は XY+space。それ以降がパス
        $path = if ($line.Length -gt 3) { $line.Substring(3) } else { '' }
        # rename "A -> B" -> B 側を採用
        if ($path -match ' -> ') {
            $path = ($path -split ' -> ')[-1]
        }
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $uncommitted += $path
        }
    }

    # main から HEAD までのコミット済み差分
    $committed = @()
    if ($base) {
        $diffOutput = & git diff --name-only "$base..HEAD" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $committed = @($diffOutput) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }
    }

    $allChanged = @($committed + $uncommitted) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique

    if ($allChanged.Count -eq 0) { exit 0 }

    $plugins = $allChanged |
        Where-Object { $_ -like 'plugins/*' } |
        ForEach-Object { ($_ -split '/')[1] } |
        Sort-Object -Unique

    if ($plugins.Count -eq 0) { exit 0 }
    if (-not $base) { exit 0 }

    $warnings = @()
    foreach ($plugin in $plugins) {
        $pjson = "plugins/$plugin/.claude-plugin/plugin.json"
        if (-not (Test-Path -LiteralPath $pjson -PathType Leaf)) { continue }

        # main の version
        $oldVersion = ''
        try {
            $oldContent = & git show "${base}:${pjson}" 2>$null
            if ($LASTEXITCODE -eq 0 -and $oldContent) {
                $joined = ($oldContent -join "`n")
                $oldJson = $joined | ConvertFrom-Json -ErrorAction Stop
                $oldVersion = [string]$oldJson.version
            }
        } catch {
            $oldVersion = ''
        }

        # main 側に plugin.json 不在 (新規プラグイン追加中) -> 通過
        if ([string]::IsNullOrEmpty($oldVersion)) { continue }

        # 現在の version
        $newVersion = ''
        try {
            $newJson = Get-Content -LiteralPath $pjson -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            $newVersion = [string]$newJson.version
        } catch {
            $newVersion = ''
        }

        if ($oldVersion -eq $newVersion) {
            $warnings += "  - ${plugin}: ブランチ全体で plugin.json の version が main から変わっていません (現在 $oldVersion のまま)"
        }
    }

    if ($warnings.Count -eq 0) { exit 0 }

    $msg = @"
[extension-toolkit hook] バージョン更新漏れの可能性を検出:
$($warnings -join "`n")
versioning.md の方針: すべてのコミットで plugin.json の version を更新する。
コミット前に該当プラグインの plugin.json を更新してください。
 (更新基準: メジャー = 新スキル/新コマンド/新 SSOT、マイナー = 既存拡張、パッチ = バグ修正等)
"@

    [Console]::Error.WriteLine($msg)
} catch {
    # フェイルオープン
}

exit 0
