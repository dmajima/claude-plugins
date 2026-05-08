#Requires -Version 7.0
<#
.SYNOPSIS
    対話 TUI（tui.ps1）を新規 PowerShell ウィンドウで起動する。

.DESCRIPTION
    Claude Code の Bash ツール経由ではターミナル入力が受け付けられないため、
    別プロセスの PowerShell ウィンドウを起動して tui.ps1 をそこで実行する。
    Windows Terminal が利用可能ならそちらを優先し、無ければ pwsh を直接 Start-Process する。

    呼び出し元（aggregate コマンド or skill）は本スクリプトを起動するだけで、
    すぐに復帰する（TUI ウィンドウは独立して動作）。

.PARAMETER SessionId
.PARAMETER ProjectKey
.PARAMETER NoNewWindow
    指定時は新規ウィンドウを開かず、現プロセスで tui.ps1 を直接実行する。
    既に対話 PowerShell ターミナルから起動された場合に使う。
#>
[CmdletBinding()]
param(
    [string]$SessionId,
    [string]$ProjectKey,
    [switch]$NoNewWindow
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Bash 経由起動時にも UTF-8 で stdout に書けるよう、Console の Out を UTF-8 StreamWriter に差し替える
$utf8 = [System.Text.UTF8Encoding]::new($false)
$utf8Writer = [System.IO.StreamWriter]::new([Console]::OpenStandardOutput(), $utf8)
$utf8Writer.AutoFlush = $true
[Console]::SetOut($utf8Writer)

$scriptDir = Split-Path -Parent $PSCommandPath
$tuiPath = Join-Path $scriptDir 'tui.ps1'

if (-not (Test-Path $tuiPath)) {
    Write-Host "tui.ps1 が見つかりません: $tuiPath" -ForegroundColor Red
    exit 1
}

# tui.ps1 への引数を組み立てる
$tuiArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tuiPath)
if ($SessionId)  { $tuiArgs += @('-SessionId', $SessionId) }
if ($ProjectKey) { $tuiArgs += @('-ProjectKey', $ProjectKey) }

if ($NoNewWindow) {
    # 現プロセスで直接実行
    & pwsh @tuiArgs
    exit $LASTEXITCODE
}

# 新規ウィンドウで起動
# 優先順位:
#   1. Windows Terminal (wt.exe) — 新規タブで起動
#   2. pwsh の Start-Process — 新規 conhost ウィンドウで起動
$wt = Get-Command 'wt.exe' -ErrorAction SilentlyContinue

if ($wt) {
    # wt -w 0 nt --title "..." pwsh ...
    $wtArgs = @(
        '-w', '0',
        'nt',
        '--title', 'Claude Code Session Usage',
        'pwsh'
    ) + $tuiArgs

    Start-Process -FilePath $wt.Source -ArgumentList $wtArgs -WindowStyle Normal | Out-Null
    Write-Host '対話 TUI を Windows Terminal の新規タブで起動しました。'
    Write-Host '  - [c] でクリップボードへコピー'
    Write-Host '  - [r] で再集計'
    Write-Host '  - [q] / ESC で閉じる'
} else {
    # pwsh を新規ウィンドウで起動
    Start-Process -FilePath 'pwsh' -ArgumentList $tuiArgs -WindowStyle Normal | Out-Null
    Write-Host '対話 TUI を新規 PowerShell ウィンドウで起動しました。'
    Write-Host '  - [c] でクリップボードへコピー'
    Write-Host '  - [r] で再集計'
    Write-Host '  - [q] / ESC で閉じる'
}
