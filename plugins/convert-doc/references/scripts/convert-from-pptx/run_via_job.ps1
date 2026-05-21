<#
.SYNOPSIS
    convert_from_pptx.py を Start-Job 経由で起動するラッパー.

.DESCRIPTION
    Windows + PowerShell + Python + python-pptx の組み合わせで、
    `Start-Process -NoNewWindow` または `&` 演算子 + ファイルリダイレクトで
    Python を子プロセスとして起動すると、`python-pptx.Presentation()` 呼び出しで
    プロセスがハングして終了しない既知の事象がある.

    Start-Job 経由（PowerShell の子 pwsh プロセスが Python を呼ぶ二段構成）なら
    この事象を回避できることが本リポジトリの調査セッションで実証済み
    （.claude/.local/work/20260521_01_convert_from_pptx_hung_repro/ 参照）.

.PARAMETER InputPath
    入力 PPTX ファイルのパス（必須）.

.PARAMETER OutputPath
    出力 Markdown ファイルのパス（必須）.

.PARAMETER PythonExe
    venv の python.exe へのパス. 環境変数 `CONVERT_FROM_PPTX_PYTHON` でも指定可.

.PARAMETER TimeoutSec
    ジョブのタイムアウト秒数（既定 600 = 10 分）.
    環境変数 `CONVERT_FROM_PPTX_TIMEOUT_SEC` でも指定可.

.PARAMETER ExtraArgs
    convert_from_pptx.py に渡す追加オプション（--no-mermaid / --include-notes 等）.

.EXAMPLE
    pwsh -NoProfile -File run_via_job.ps1 `
      -InputPath "input.pptx" -OutputPath "output.md" `
      -PythonExe "$venv\Scripts\python.exe"

.EXAMPLE
    pwsh -NoProfile -File run_via_job.ps1 `
      "input.pptx" "output.md" -PythonExe "$venv\Scripts\python.exe" `
      --no-mermaid --include-notes

.NOTES
    SECURITY: 入力パスは convert_from_pptx.py 側でパストラバーサル検査を行う.
    本ラッパーは引数を素通しするのみで、独自のパス検証は行わない.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)] [string]$InputPath,
    [Parameter(Mandatory=$true, Position=1)] [string]$OutputPath,
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

# Timeout 解決
if ($TimeoutSec -le 0) {
    if ($env:CONVERT_FROM_PPTX_TIMEOUT_SEC) {
        $TimeoutSec = [int]$env:CONVERT_FROM_PPTX_TIMEOUT_SEC
    } else {
        $TimeoutSec = 600
    }
}

# convert_from_pptx.py のパス（ラッパーと同一ディレクトリ）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$convertScript = Join-Path $scriptDir "convert_from_pptx.py"
if (-not (Test-Path $convertScript)) {
    Write-Error "convert_from_pptx.py not found at expected location: $convertScript"
    exit 2
}

# Python へ渡す引数を組み立て
$pythonArgs = @($InputPath, $OutputPath)
if ($ExtraArgs) {
    # 先頭の "--" セパレータ（PowerShell から渡される場合）は除去
    if ($ExtraArgs[0] -eq "--") {
        $ExtraArgs = $ExtraArgs[1..($ExtraArgs.Count - 1)]
    }
    $pythonArgs += $ExtraArgs
}

# Start-Job で convert_from_pptx.py を実行
# `2>&1` で Python の stderr を stdout に統合してから ToString() で
# 文字列化し、PowerShell の Error ストリームに飛んで Receive-Job で
# 拾えなくなる事態を防ぐ.
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
} -ArgumentList $PythonExe, $convertScript, (,$pythonArgs)

# 完了待ち
$completed = Wait-Job $job -Timeout $TimeoutSec
if (-not $completed) {
    Write-Error "convert_from_pptx.py timed out after $TimeoutSec sec"
    Stop-Job $job
    $partial = Receive-Job $job -ErrorAction SilentlyContinue
    if ($partial) { Write-Output $partial }
    Remove-Job $job -Force
    exit 124
}

# 結果を呼び出し元に転送
$output = Receive-Job $job -ErrorAction SilentlyContinue

# 終了コードは output の最終要素として返却（return $LASTEXITCODE による）
$rc = 0
if ($output -is [array] -and $output.Count -gt 0) {
    $lastItem = $output[-1]
    if ($lastItem -is [int]) {
        $rc = [int]$lastItem
        # 最終要素（int の終了コード）は出力から除外して通常出力のみ転送
        if ($output.Count -gt 1) {
            $output[0..($output.Count - 2)] | Write-Output
        }
    } else {
        Write-Output $output
    }
} elseif ($output -is [int]) {
    $rc = [int]$output
} elseif ($output) {
    Write-Output $output
}

Remove-Job $job -Force
exit $rc
