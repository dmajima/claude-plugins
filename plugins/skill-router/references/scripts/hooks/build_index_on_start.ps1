# build_index_on_start.ps1 - SessionStart hook entry for skill-router (PowerShell 7+ 版).
# Triggers build_index.py to refresh the routing index on startup / resume / clear.
#
# venv lifecycle (see references/scripts/lib/venv_lifecycle.py):
#   1. session-reset clears the previous session's rebuild counter so this
#      session has its full REBUILD_LIMIT (3) budget again.
#   2. ensure constructs the venv only when requirements.txt has active deps
#      (no-op while the plugin remains stdlib-only).
#   3. python-bin selects the venv python if available, else system python.
#   4. On a Python-traceback environment error (ModuleNotFoundError /
#      ImportError as the terminating exception), rebuild the venv up to
#      REBUILD_LIMIT times and retry once.
#
# Fail-open: any error must not block the session start.

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

try {
    $pluginRoot = $env:CLAUDE_PLUGIN_ROOT
    if ([string]::IsNullOrEmpty($pluginRoot)) {
        # Fallback: script-dir/../../..
        $pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
    }

    # PowerShell + Windows ネイティブパスのため、cygpath 相当の変換は不要。

    $pythonBin = $null
    $py3 = Get-Command python3 -ErrorAction SilentlyContinue
    $py  = Get-Command python  -ErrorAction SilentlyContinue
    if ($py3) {
        $pythonBin = $py3.Source
    } elseif ($py) {
        $pythonBin = $py.Source
    }
    if ([string]::IsNullOrEmpty($pythonBin)) { exit 0 }

    $lifecycle = Join-Path $pluginRoot 'references/scripts/lib/venv_lifecycle.py'
    $target    = Join-Path $pluginRoot 'references/scripts/lib/build_index.py'

    $stderrTemp = [System.IO.Path]::GetTempFileName()
    $cleanup = $true
    try {
        & $pythonBin $lifecycle session-reset --plugin-root $pluginRoot *>$null
        & $pythonBin $lifecycle ensure --plugin-root $pluginRoot *>$null

        $venvPy = $null
        try {
            $venvPy = (& $pythonBin $lifecycle python-bin --plugin-root $pluginRoot --no-construct 2>$null) -as [string]
        } catch {}
        if ([string]::IsNullOrWhiteSpace($venvPy)) { $venvPy = $pythonBin }

        # Run build_index.py; capture stderr to temp file
        & $venvPy $target 2>$stderrTemp 1>$null
        $buildRc = $LASTEXITCODE

        if ($buildRc -ne 0) {
            & $pythonBin $lifecycle is-env-error --stderr-file $stderrTemp *>$null
            $isEnvError = ($LASTEXITCODE -eq 0)
            if ($isEnvError) {
                & $pythonBin $lifecycle rebuild --plugin-root $pluginRoot *>$null
                try {
                    $venvPy = (& $pythonBin $lifecycle python-bin --plugin-root $pluginRoot --no-construct 2>$null) -as [string]
                } catch {}
                if ([string]::IsNullOrWhiteSpace($venvPy)) { $venvPy = $pythonBin }
                & $venvPy $target *>$null
            }
        }
    } finally {
        if ($cleanup -and (Test-Path -LiteralPath $stderrTemp -PathType Leaf)) {
            Remove-Item -LiteralPath $stderrTemp -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    # フェイルオープン
}

exit 0
