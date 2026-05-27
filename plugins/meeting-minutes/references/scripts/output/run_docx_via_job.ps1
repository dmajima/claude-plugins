param(
    [Parameter(Mandatory=$true)]
    [string]$PythonExe,
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,
    [Parameter(Mandatory=$true)]
    [string]$InputJson,
    [Parameter(Mandatory=$true)]
    [string]$OutputDocx,
    [string]$TemplatePath = "",
    [int]$TimeoutSec = 120
)

$jobArgs = @($InputJson, $OutputDocx, $TemplatePath)

$job = Start-Job -ScriptBlock {
    param($py, $script, $args_)
    & chcp.com 65001 | Out-Null
    [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    $env:PYTHONUTF8 = "1"
    $env:PYTHONIOENCODING = "utf-8"
    $cmdArgs = @("--input", $args_[0], "--output", $args_[1])
    if ($args_[2]) { $cmdArgs += @("--template", $args_[2]) }
    & $py -u $script @cmdArgs
    return $LASTEXITCODE
} -ArgumentList $PythonExe, $ScriptPath, (,$jobArgs)

$completed = Wait-Job $job -Timeout $TimeoutSec
if (-not $completed) {
    Stop-Job $job
    Remove-Job $job -Force
    throw "[run_docx_via_job] Timed out after ${TimeoutSec}s"
}
$output = Receive-Job $job
$exitCode = $output | Where-Object { $_ -is [int] } | Select-Object -Last 1
$textOutput = $output | Where-Object { $_ -isnot [int] }
if ($textOutput) { $textOutput | ForEach-Object { Write-Host $_ } }
Remove-Job $job -Force

if ($exitCode -and $exitCode -ne 0) {
    throw "[run_docx_via_job] Script exited with code $exitCode"
}
Write-Host "[run_docx_via_job] Done."
