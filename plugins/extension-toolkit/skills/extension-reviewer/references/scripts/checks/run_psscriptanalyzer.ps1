#requires -Version 7

<#
.SYNOPSIS
    PSScriptAnalyzer 起動ラッパー（B-1: improvement-backlog 由来）

.DESCRIPTION
    対象ディレクトリ/ファイル配下の .ps1 / .psm1 / .psd1 を PSScriptAnalyzer で
    走査し、結果を JSON ファイルに出力する。run_checks.py から subprocess で
    呼び出される設計（Python 直接呼出だと PowerShell モジュール解決が困難なため）。

    PSScriptAnalyzer モジュール未インストール時は status=skipped で
    フェイルオープン終了（run_checks 全体を止めない）。

.PARAMETER Target
    走査対象のディレクトリまたは .ps1 / .psm1 / .psd1 ファイル

.PARAMETER Output
    結果 JSON を書き出すファイルパス

.OUTPUTS
    JSON ファイル: { status: "ok"|"skipped", reason?, issues: [...] }
    各 issue は { severity, item, file, line, detail } 形式で run_checks.py の
    IssueCollector と互換。

.NOTES
    検出契機: 2026-05-18 のセッションで sync-settings/sync.ps1 の
    TrimStart(string) 引数誤用（実際は char[]）が静的レビュー 6 サイクルを
    素通りしてデモで初めて発覚した事例。同種の AST ベース静的検出を導入する。

    集計重大度マッピング:
      PSA Error       → High
      PSA Warning     → Medium
      PSA Information → Low
#>

param(
    [Parameter(Mandatory)]
    [string]$Target,

    [Parameter(Mandatory)]
    [string]$Output
)

$ErrorActionPreference = 'Stop'
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Result {
    param(
        [Parameter(Mandatory)] [hashtable]$Data,
        [Parameter(Mandatory)] [string]$Path
    )
    $Data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8
}

# 1. PSScriptAnalyzer モジュール存在確認
$psa = Get-Module -ListAvailable -Name PSScriptAnalyzer | Select-Object -First 1
if (-not $psa) {
    Write-Output '[SKIP] PSScriptAnalyzer not installed (Install-Module -Name PSScriptAnalyzer -Scope CurrentUser を推奨)'
    Write-Result -Data @{
        status = 'skipped'
        reason = 'PSScriptAnalyzer module not installed'
        issues = @()
    } -Path $Output
    exit 0
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

# 2. ターゲット存在確認
if (-not (Test-Path -LiteralPath $Target)) {
    Write-Output "[ERROR] target not found: $Target"
    Write-Result -Data @{
        status = 'error'
        reason = "target not found: $Target"
        issues = @()
    } -Path $Output
    exit 2
}

# 3. 設定ファイル解決
$settings = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'
$useSettings = Test-Path -LiteralPath $settings

# 4. PSScriptAnalyzer 実行
try {
    $invokeArgs = @{
        Path        = $Target
        Recurse     = $true
        ErrorAction = 'Continue'
    }
    if ($useSettings) {
        $invokeArgs.Settings = $settings
    }
    $results = Invoke-ScriptAnalyzer @invokeArgs
}
catch {
    Write-Output "[ERROR] Invoke-ScriptAnalyzer failed: $_"
    Write-Result -Data @{
        status = 'error'
        reason = "Invoke-ScriptAnalyzer failed: $_"
        issues = @()
    } -Path $Output
    exit 3
}

# 5. 結果を IssueCollector 互換形式に変換
$issues = @()
foreach ($r in $results) {
    $severity = switch ($r.Severity) {
        'Error'       { 'High' }
        'Warning'     { 'Medium' }
        'Information' { 'Low' }
        default       { 'Low' }
    }
    $issues += [ordered]@{
        severity = $severity
        item     = "PSA-$($r.RuleName)"
        file     = "$($r.ScriptPath)"
        line     = [int]$r.Line
        detail   = "$($r.Message)"
    }
}

# 6. JSON 出力
Write-Result -Data @{
    status = 'ok'
    settings_used = $useSettings
    issues = $issues
} -Path $Output

Write-Output ("[OK] PSScriptAnalyzer: {0} issues" -f $issues.Count)
exit 0
