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

# SEC-M2: PythonExe は .exe 拡張子であることを検証.
# Windows 上で `Test-Path` のみだと、攻撃者が環境変数を汚染できる場合に
# 任意の実行ファイル（.bat / .cmd / シェルスクリプト等）が Python 名義で
# 起動されうるリスクがあるため、拡張子レベルでの最低限の境界を設ける.
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
    # IMPL-M1: Stop-Job は非同期のため、Wait-Job で kill 完了を待つ.
    # これを挟まないと続く Receive-Job が Running 状態の partial データを読み、
    # 想定外のレースで終了コードを取り違える可能性がある.
    Stop-Job $job | Out-Null
    Wait-Job $job -Timeout 10 | Out-Null
    $partial = Receive-Job $job -ErrorAction SilentlyContinue
    if ($partial) { Write-Output $partial }
    Remove-Job $job -Force
    exit 124
}

# 結果を呼び出し元に転送
$output = Receive-Job $job -ErrorAction SilentlyContinue

# IMPL-M2: 終了コードは output の最終要素として返却（return $LASTEXITCODE による）.
# PowerShell の Receive-Job はジョブ境界をまたぐデシリアライズで int を long に
# 昇格する場合があり、`-is [int]` のみで判定すると終了コードが拾えないことが
# ある (rc=0 で素通り). 数値型 [int]/[long]/[short]/[byte] を許容し、
# 0-255 の妥当な exit code 範囲に収まるものだけを終了コードとみなす.
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
        # 最終要素（exit code）は出力から除外して通常出力のみ転送
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
