# run_via_job.ps1 - convert_from_pptx.py を Start-Job 経由で起動するラッパー (PowerShell 7+ 版)
#
# Windows + PowerShell + python-pptx の Start-Process -NoNewWindow ハング事象を回避するため、
# Start-Job 二段プロセス構成で python.exe を起動する。
# 詳細: ~/.claude/rules/tools/python-subprocess-hang-windows.md
#
# 使い方:
#   pwsh -NoProfile -File run_via_job.ps1 -InputPath <input.pptx> -OutputPath <output.md> -PythonExe <path> [-TimeoutSec <sec>] [-- extra args...]

param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

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
$convertScript = Join-Path $scriptDir 'convert_from_pptx.py'
if (-not (Test-Path -LiteralPath $convertScript -PathType Leaf)) {
    [Console]::Error.WriteLine("convert_from_pptx.py not found at: $convertScript")
    exit 2
}

$jobArgs = @($InputPath, $OutputPath) + $ExtraArgs

$job = Start-Job -ScriptBlock {
    param($py, $script, $jobArgs)
    & chcp.com 65001 | Out-Null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    $env:PYTHONUTF8 = '1'
    $env:PYTHONIOENCODING = 'utf-8'
    & $py -u $script @jobArgs 2>&1
    return $LASTEXITCODE
} -ArgumentList $PythonExe, $convertScript, (,$jobArgs)

$completed = Wait-Job $job -Timeout $TimeoutSec
if (-not $completed) {
    Stop-Job $job -Confirm:$false
    Remove-Job $job -Force
    [Console]::Error.WriteLine("convert_from_pptx.py timed out after $TimeoutSec sec")
    exit 124
}

$output = Receive-Job $job
$exitCode = $job.ChildJobs[0].JobStateInfo.Reason
Remove-Job $job -Force

if ($output) {
    $output | ForEach-Object { Write-Output $_ }
}

$rc = if ($output -is [array] -and $output[-1] -is [int]) { $output[-1] } else { 0 }
exit $rc
