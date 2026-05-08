#Requires -Version 7.0
<#
.SYNOPSIS
    Claude Code セッション使用量の対話 TUI（フルスクリーン + キー入力受付）。

.DESCRIPTION
    /doctor 風のフルスクリーン表示で集計結果を提示し、キー操作で
    クリップボードコピー・再集計・終了を行う。
    本スクリプトは tty 接続された PowerShell ターミナルで実行される必要がある
    （Claude Code の Bash ツール経由では stdin が閉じているため、launch.ps1 が
     新規 PowerShell ウィンドウを起動して本スクリプトをそこで動かす）。

.PARAMETER SessionId
    対象セッションID。aggregate.ps1 にそのまま渡す。

.PARAMETER ProjectKey
    プロジェクトキー。aggregate.ps1 にそのまま渡す。
#>
[CmdletBinding()]
param(
    [string]$SessionId,
    [string]$ProjectKey
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ウィンドウタイトルを設定
$Host.UI.RawUI.WindowTitle = 'Claude Code  Session Usage'

$scriptDir = Split-Path -Parent $PSCommandPath
$aggregatePath = Join-Path (Split-Path -Parent $scriptDir) 'aggregate/aggregate.ps1'

if (-not (Test-Path $aggregatePath)) {
    Write-Host "aggregate.ps1 が見つかりません: $aggregatePath" -ForegroundColor Red
    [System.Console]::ReadKey($true) | Out-Null
    exit 1
}

# 集計実行（共通処理）
function Invoke-Aggregate {
    try {
        return & $aggregatePath -SessionId $SessionId -ProjectKey $ProjectKey
    } catch {
        return "  [ERROR] 集計失敗: $($_.Exception.Message)"
    }
}

# 描画
function Draw {
    param(
        [string]$Body,
        [string]$Status = '',
        [ConsoleColor]$StatusColor = [ConsoleColor]::Gray
    )
    Clear-Host

    Write-Host $Body

    Write-Host ''
    Write-Host ('─' * 60) -ForegroundColor DarkGray

    if ($Status) {
        Write-Host "  $Status" -ForegroundColor $StatusColor
        Write-Host ('─' * 60) -ForegroundColor DarkGray
    }

    Write-Host '  [c] Copy clipboard   [r] Refresh   [q] Quit (or ESC)' -ForegroundColor Cyan
}

# ---- 初期描画 ----
$rendered = Invoke-Aggregate
Draw -Body $rendered -Status ('Generated at ' + (Get-Date -Format 'HH:mm:ss')) -StatusColor DarkGray

# ---- キーループ ----
while ($true) {
    try {
        $key = [System.Console]::ReadKey($true)
    } catch {
        Write-Host ''
        Write-Host '  対話モードを利用できません（stdin が閉鎖されています）' -ForegroundColor Yellow
        Write-Host '  このスクリプトは PowerShell ターミナルから直接起動してください。' -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        return
    }

    if ($key.Key -eq [ConsoleKey]::Escape) { return }

    switch ($key.KeyChar) {
        'q' { return }
        'Q' { return }

        'c' {
            try {
                $rendered | Set-Clipboard
                Draw -Body $rendered -Status '[OK] Copied to clipboard' -StatusColor Green
            } catch {
                Draw -Body $rendered -Status ("[NG] Copy failed: " + $_.Exception.Message) -StatusColor Red
            }
        }
        'C' {
            try {
                $rendered | Set-Clipboard
                Draw -Body $rendered -Status '[OK] Copied to clipboard' -StatusColor Green
            } catch {
                Draw -Body $rendered -Status ("[NG] Copy failed: " + $_.Exception.Message) -StatusColor Red
            }
        }

        'r' {
            $rendered = Invoke-Aggregate
            Draw -Body $rendered -Status ('[OK] Refreshed at ' + (Get-Date -Format 'HH:mm:ss')) -StatusColor Green
        }
        'R' {
            $rendered = Invoke-Aggregate
            Draw -Body $rendered -Status ('[OK] Refreshed at ' + (Get-Date -Format 'HH:mm:ss')) -StatusColor Green
        }

        default {
            # 不明キー - そのまま継続
        }
    }
}
