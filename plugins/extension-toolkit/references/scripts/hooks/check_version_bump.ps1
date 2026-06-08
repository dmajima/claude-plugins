# check_version_bump.ps1 - Stop hook (PowerShell version)
#
#
# Claude のターン終了時、plugins/{name}/ 配下に未コミット変更があり、
# かつ plugin.json の version が未更新の場合に stderr で警告する。
# 設計: フェイルオープン (exit 0、Claude のターンを止めない)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# stdin を読み捨て (ファイルディスクリプタ詰まり防止)
try { [Console]::In.ReadToEnd() | Out-Null } catch {}

# git 利用不可ならスキップ
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) { exit 0 }

# リポジトリ外ならスキップ
$inRepo = & git rev-parse --is-inside-work-tree 2>$null
if ($inRepo -ne 'true') { exit 0 }

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
$uncommitted = @()
$statusLines = & git status --porcelain 2>$null
if ($statusLines) {
    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $path = $line.Substring(3)
        # rename "A -> B" -> B 側を採用
        if ($path -match ' -> ') {
            $path = ($path -split ' -> ')[-1]
        }
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $uncommitted += $path
        }
    }
}

# main から HEAD までのコミット済み差分
$committed = @()
if ($base -ne '') {
    $diffLines = & git diff --name-only "${base}..HEAD" 2>$null
    if ($diffLines) {
        foreach ($line in $diffLines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $committed += $line
            }
        }
    }
}

# all_changed (重複除去)
$seen = @{}
$allChanged = @()
foreach ($p in ($committed + $uncommitted)) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if (-not $seen.ContainsKey($p)) {
        $seen[$p] = $true
        $allChanged += $p
    }
}

if ($allChanged.Count -eq 0) { exit 0 }

# プラグイン名抽出
$pluginSeen = @{}
$plugins = @()
foreach ($p in $allChanged) {
    if ($p -match '^plugins/') {
        $remainder = $p.Substring('plugins/'.Length)
        $pluginName = $remainder.Split('/')[0]
        if ($pluginName -ne '' -and -not $pluginSeen.ContainsKey($pluginName)) {
            $pluginSeen[$pluginName] = $true
            $plugins += $pluginName
        }
    }
}

if ($plugins.Count -eq 0) { exit 0 }
if ($base -eq '') { exit 0 }

$warnings = @()
foreach ($plugin in $plugins) {
    $pjson = "plugins/$plugin/.claude-plugin/plugin.json"
    if (-not (Test-Path $pjson)) { continue }

    # main の version
    $oldVersion = ''
    $oldContent = & git show "${base}:${pjson}" 2>$null
    if ($LASTEXITCODE -eq 0 -and $oldContent) {
        try {
            $oldContentStr = if ($oldContent -is [array]) { $oldContent -join "`n" } else { [string]$oldContent }
            $oldObj = $oldContentStr | ConvertFrom-Json -ErrorAction Stop
            if ($oldObj.version) { $oldVersion = $oldObj.version }
        } catch {}
    }
    # main 側に plugin.json 不在 (新規プラグイン追加中) -> 通過
    if ($oldVersion -eq '') { continue }

    # 現在の version
    $newVersion = ''
    try {
        $newObj = Get-Content -LiteralPath $pjson -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($newObj.version) { $newVersion = $newObj.version }
    } catch {}

    if ($oldVersion -eq $newVersion) {
        $warnings += "  - ${plugin}: ブランチ全体で plugin.json の version が main から変わっていません (現在 $oldVersion のまま)"
    }
}

if ($warnings.Count -eq 0) { exit 0 }

$warningText = $warnings -join "`n"
[Console]::Error.WriteLine(@"
[extension-toolkit hook] バージョン更新漏れの可能性を検出:
$warningText
versioning.md の方針: すべてのコミットで plugin.json の version を更新する。
コミット前に該当プラグインの plugin.json を更新してください。
 (更新基準: メジャー = 新スキル/新コマンド/新 SSOT、マイナー = 既存拡張、パッチ = バグ修正等)
"@)

exit 0
