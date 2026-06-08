# run_verify_via_job.ps1 - verify_md.py を Start-Job 経由で起動するラッパー (PowerShell 7+ 版)
#
# Windows + PowerShell + python-pptx の Start-Process -NoNewWindow ハング事象を回避するため、
# Start-Job 二段プロセス構成で python.exe を起動する。
# 設計と挙動は run_via_job.ps1 と対称。
#
# 使い方:
#   pwsh -NoProfile -File run_verify_via_job.ps1 -PptxPath <input.pptx> -MdPath <md.md> -PythonExe <path> [-TimeoutSec <sec>] [-- extra args...]

param(
    [Parameter(Mandatory = $true)]
    [string]$PptxPath,

    [Parameter(Mandatory = $true)]
    [string]$MdPath,

    [Parameter(Mandatory = $true)]
    [string]$PythonExe,

    [Parameter()]
    [int]$TimeoutSec = 0,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs = @()
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
    [Console]::Error.WriteLine("PythonExe not found: $PythonExe")
    exit 2
}

if ($PythonExe -notmatch '\.exe$') {
    [Console]::Error.WriteLine("PythonExe must be a .exe file: $PythonExe")
    exit 2
}

if ($TimeoutSec -le 0) {
    if ($env:CONVERT_FROM_PPTX_TIMEOUT_SEC -and $env:CONVERT_FROM_PPTX_TIMEOUT_SEC -match '^\d+$') {
        $TimeoutSec = [int]$env:CONVERT_FROM_PPTX_TIMEOUT_SEC
    }
    if ($TimeoutSec -le 0) { $TimeoutSec = 600 }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$verifyScript = Join-Path $scriptDir 'verify_md.py'
if (-not (Test-Path -LiteralPath $verifyScript -PathType Leaf)) {
    [Console]::Error.WriteLine("verify_md.py not found at: $verifyScript")
    exit 2
}

$jobArgs = @($PptxPath, $MdPath) + $ExtraArgs

$job = Start-Job -ScriptBlock {
    param($py, $script, $jobArgs)
    & chcp.com 65001 | Out-Null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    $env:PYTHONUTF8 = '1'
    $env:PYTHONIOENCODING = 'utf-8'
    & $py -u $script @jobArgs 2>&1
    return $LASTEXITCODE
} -ArgumentList $PythonExe, $verifyScript, (,$jobArgs)

$completed = Wait-Job $job -Timeout $TimeoutSec
if (-not $completed) {
    Stop-Job $job -Confirm:$false
    Remove-Job $job -Force
    [Console]::Error.WriteLine("verify_md.py timed out after $TimeoutSec sec")
    exit 124
}

$output = Receive-Job $job
Remove-Job $job -Force

if ($output) {
    $output | ForEach-Object { Write-Output $_ }
}

$rc = if ($output -is [array] -and $output[-1] -is [int]) { $output[-1] } else { 0 }
exit $rc
