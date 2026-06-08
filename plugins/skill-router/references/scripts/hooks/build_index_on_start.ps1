# build_index_on_start.ps1 - SessionStart hook for skill-router (PowerShell 版)
#
#
# venv ライフサイクル管理 (references/scripts/lib/venv_lifecycle.py):
#   session-reset -> ensure -> python-bin -> build_index 実行
#   失敗時は env-error 判定 -> rebuild -> 再実行
#
# Fail-open: any error must not block the session start.

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# --- Resolve plugin root ---
$pluginRoot = $env:CLAUDE_PLUGIN_ROOT
if (-not $pluginRoot) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $pluginRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..') -ErrorAction SilentlyContinue).Path
}
if (-not $pluginRoot) { exit 0 }

# --- Find system python ---
$pythonBin = $null
$py3 = Get-Command python3 -ErrorAction SilentlyContinue
if ($py3) { $pythonBin = $py3.Source }
if (-not $pythonBin) {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) { $pythonBin = $py.Source }
}
if (-not $pythonBin) { exit 0 }

$lifecycle = Join-Path $pluginRoot 'references/scripts/lib/venv_lifecycle.py'
$target    = Join-Path $pluginRoot 'references/scripts/lib/build_index.py'

# --- Temp file for stderr capture ---
$stderrTemp = $null
try {
    $stderrTemp = [System.IO.Path]::GetTempFileName()
} catch {
    $stderrTemp = Join-Path $env:TEMP "skill_router_build_$PID.tmp"
}

try {
    # session-reset
    & $pythonBin $lifecycle 'session-reset' '--plugin-root' $pluginRoot 2>&1 | Out-Null

    # ensure venv
    & $pythonBin $lifecycle 'ensure' '--plugin-root' $pluginRoot 2>&1 | Out-Null

    # get venv python
    $venvPy = & $pythonBin $lifecycle 'python-bin' '--plugin-root' $pluginRoot '--no-construct' 2>$null
    if (-not $venvPy -or ($venvPy -replace '\s','') -eq '') { $venvPy = $pythonBin }

    # run build_index, capture stderr to temp file
    $buildProc = Start-Process -FilePath $venvPy -ArgumentList "`"$target`"" `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput 'NUL' `
        -RedirectStandardError $stderrTemp
    $buildRc = $buildProc.ExitCode

    if ($buildRc -ne 0) {
        # check if env-error
        & $pythonBin $lifecycle 'is-env-error' '--stderr-file' $stderrTemp 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            # rebuild venv
            & $pythonBin $lifecycle 'rebuild' '--plugin-root' $pluginRoot 2>&1 | Out-Null

            # get new venv python
            $venvPy = & $pythonBin $lifecycle 'python-bin' '--plugin-root' $pluginRoot '--no-construct' 2>$null
            if (-not $venvPy -or ($venvPy -replace '\s','') -eq '') { $venvPy = $pythonBin }

            # retry build_index
            & $venvPy $target 2>&1 | Out-Null
        }
    }
} finally {
    if ($stderrTemp -and (Test-Path $stderrTemp -ErrorAction SilentlyContinue)) {
        Remove-Item $stderrTemp -Force -ErrorAction SilentlyContinue
    }
}

exit 0
