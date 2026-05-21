<#
.SYNOPSIS
    verify_md.py を Start-Job 経由で起動するラッパー.

.DESCRIPTION
    verify_md.py は内部で python-pptx を使うため、convert_from_pptx.py と同じ
    「Windows + PowerShell + Start-Process -NoNewWindow / & + ファイルリダイレクト
    での起動時に python-pptx.Presentation() でハング」事象が発生しうる.

    本ラッパーは Start-Job 経由（PowerShell の子 pwsh プロセスが Python を呼ぶ
    二段構成）でハングを回避する. 設計と挙動は `run_via_job.ps1` と対称.

    詳細は `run_via_job.ps1` のヘッダ / グローバルルール
    `~/.claude/rules/tools/python-subprocess-hang-windows.md` を参照.

.PARAMETER PptxPath
    入力 PPTX ファイルのパス（必須）.

.PARAMETER MdPath
    検証対象 Markdown ファイルのパス（必須）.

.PARAMETER PythonExe
    venv の python.exe へのパス. 環境変数 `CONVERT_FROM_PPTX_PYTHON` でも指定可.

.PARAMETER TimeoutSec
    ジョブのタイムアウト秒数（既定 600 = 10 分）.
    環境変数 `CONVERT_FROM_PPTX_TIMEOUT_SEC` でも指定可.

.PARAMETER ExtraArgs
    verify_md.py に渡す追加オプション（--report / --threshold / --max-missing-shown 等）.

.EXAMPLE
    pwsh -NoProfile -File run_verify_via_job.ps1 `
      -PptxPath "input.pptx" -MdPath "output.md" `
      -PythonExe "$venv\Scripts\python.exe" `
      --report "report.json" --threshold 0.85

.NOTES
    SECURITY: 入力パスは verify_md.py 側でパストラバーサル / symlink 検証を行う.
    本ラッパーは引数を素通しするのみで、独自のパス検証は行わない.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)] [string]$PptxPath,
    [Parameter(Mandatory=$true, Position=1)] [string]$MdPath,
    [string]$PythonExe,
    [int]$TimeoutSec = 0,
    [Parameter(ValueFromRemainingArguments=$true)] [string[]]$ExtraArgs
)

# 必須プリフィクス: コンソールエンコーディング
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# PythonExe 解決
if (-not $PythonExe) {
    $PythonExe = $env:CONVERT_FROM_PPTX_PYTHON
}
if (-not $PythonExe -or -not (Test-Path $PythonExe)) {
    Write-Error "PythonExe not found. Specify -PythonExe or set CONVERT_FROM_PPTX_PYTHON env var to venv python.exe path."
    exit 2
}

# SEC-M2: PythonExe は .exe 拡張子であることを検証.
if (-not ($PythonExe.ToLower().EndsWith('.exe'))) {
    Write-Error "PythonExe must be a .exe file: $PythonExe"
    exit 2
}

# Timeout 解決
if ($TimeoutSec -le 0) {
    if ($env:CONVERT_FROM_PPTX_TIMEOUT_SEC) {
        # SEC-L1: 整数変換失敗時はデフォルトにフォールバック.
        try {
            $TimeoutSec = [int]$env:CONVERT_FROM_PPTX_TIMEOUT_SEC
        } catch {
            Write-Warning "Invalid CONVERT_FROM_PPTX_TIMEOUT_SEC value, using default 600"
            $TimeoutSec = 600
        }
        if ($TimeoutSec -le 0) { $TimeoutSec = 600 }
    } else {
        $TimeoutSec = 600
    }
}

# verify_md.py のパス（ラッパーと同一ディレクトリ）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$verifyScript = Join-Path $scriptDir "verify_md.py"
if (-not (Test-Path $verifyScript)) {
    Write-Error "verify_md.py not found at expected location: $verifyScript"
    exit 2
}

# Python へ渡す引数を組み立て
$pythonArgs = @($PptxPath, $MdPath)
if ($ExtraArgs) {
    if ($ExtraArgs[0] -eq "--") {
        $ExtraArgs = $ExtraArgs[1..($ExtraArgs.Count - 1)]
    }
    $pythonArgs += $ExtraArgs
}

# Start-Job で verify_md.py を実行（`2>&1` で stderr を呼び出し元に統合）
$job = Start-Job -ScriptBlock {
    param($py, $script, $jobArgs)
    & chcp.com 65001 | Out-Null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    $env:PYTHONUTF8 = "1"
    $env:PYTHONIOENCODING = "utf-8"
    $merged = & $py -u $script @jobArgs 2>&1 | ForEach-Object { "$_" }
    $exitCode = $LASTEXITCODE
    if ($merged) { $merged | Write-Output }
    return $exitCode
} -ArgumentList $PythonExe, $verifyScript, (,$pythonArgs)

# 完了待ち
$completed = Wait-Job $job -Timeout $TimeoutSec
if (-not $completed) {
    Write-Error "verify_md.py timed out after $TimeoutSec sec"
    Stop-Job $job | Out-Null
    Wait-Job $job -Timeout 10 | Out-Null
    $partial = Receive-Job $job -ErrorAction SilentlyContinue
    if ($partial) { Write-Output $partial }
    Remove-Job $job -Force
    exit 124
}

# 結果を呼び出し元に転送
$output = Receive-Job $job -ErrorAction SilentlyContinue
$rc = 0
$isExitCode = {
    param($item)
    if ($null -eq $item) { return $false }
    if (-not ($item -is [int] -or $item -is [long] -or $item -is [short] -or $item -is [byte])) {
        return $false
    }
    return ($item -ge 0 -and $item -le 255)
}
if ($output -is [array] -and $output.Count -gt 0) {
    $lastItem = $output[-1]
    if (& $isExitCode $lastItem) {
        $rc = [int]$lastItem
        if ($output.Count -gt 1) {
            $output[0..($output.Count - 2)] | Write-Output
        }
    } else {
        Write-Output $output
    }
} elseif (& $isExitCode $output) {
    $rc = [int]$output
} elseif ($output) {
    Write-Output $output
}

Remove-Job $job -Force
exit $rc
