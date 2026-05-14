# route_prompt.ps1 - UserPromptSubmit hook entry for skill-router (PowerShell 7+ 版).
#
# CRITICAL (D2 / C3): NEVER parse stdin JSON in PowerShell. Always delegate to Python (json.load).
# PowerShell responsibilities are limited to:
#   1. Spawning the Python interpreter.
#   2. Checking the toggle (disabled) file.
#   3. Passing stdin through unchanged.
#
# venv lifecycle: this hook *consumes* an existing venv (no construction
# or rebuild here -- SessionStart owns those) and runs cleanup-if-stale at
# the very end so a venv older than 72h is removed once the plugin's
# user-facing activity finishes.
#
# Fail-open: any error must not block the user prompt.

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

# stdin を最初に読み取って保持 (子プロセスに stdin が空でも安全に進む)
$stdinPayload = [Console]::In.ReadToEnd()

try {
    $pluginRoot = $env:CLAUDE_PLUGIN_ROOT
    if ([string]::IsNullOrEmpty($pluginRoot)) {
        $pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
    }

    $pythonBin = $null
    $py3 = Get-Command python3 -ErrorAction SilentlyContinue
    $py  = Get-Command python  -ErrorAction SilentlyContinue
    if ($py3) {
        $pythonBin = $py3.Source
    } elseif ($py) {
        $pythonBin = $py.Source
    }
    if ([string]::IsNullOrEmpty($pythonBin)) { exit 0 }

    # Toggle check (resolution order matches Python build_index.resolve_base_dir)
    . (Join-Path $pluginRoot 'references/scripts/commands/resolve_base.ps1')

    if ($env:CLAUDE_PLUGIN_DATA) {
        if (Test-Path -LiteralPath (Join-Path $env:CLAUDE_PLUGIN_DATA 'disabled') -PathType Leaf) {
            exit 0
        }
    }

    $repo = Get-SkillRouterProjectRoot
    if ($repo) {
        $repoFlag = Join-Path $repo '.claude/.local/plugins/skill-router/disabled'
        if (Test-Path -LiteralPath $repoFlag -PathType Leaf) {
            exit 0
        }
    }

    $homeDir = Get-SkillRouterHomeDir
    if ($homeDir) {
        $homeFlag = Join-Path $homeDir '.claude/.local/plugins/skill-router/disabled'
        if (Test-Path -LiteralPath $homeFlag -PathType Leaf) {
            exit 0
        }
    }

    $lifecycle = Join-Path $pluginRoot 'references/scripts/lib/venv_lifecycle.py'
    $venvPy = $null
    try {
        $venvPy = (& $pythonBin $lifecycle python-bin --plugin-root $pluginRoot --no-construct 2>$null) -as [string]
    } catch {}
    if ([string]::IsNullOrWhiteSpace($venvPy)) { $venvPy = $pythonBin }

    # Spawn Python with stdin payload. Use Process for accurate stdin/stdout/stderr handling.
    $routeScript = Join-Path $pluginRoot 'references/scripts/lib/route.py'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $venvPy
    $psi.ArgumentList.Add($routeScript)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.StandardInputEncoding  = [System.Text.UTF8Encoding]::new($false)
    $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding  = [System.Text.UTF8Encoding]::new($false)

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($stdinPayload) {
        $proc.StandardInput.Write($stdinPayload)
    }
    $proc.StandardInput.Close()

    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $routeRc = $proc.ExitCode

    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }

    # Stale-venv teardown (runs after the routing call so user-facing response is not delayed)
    & $pythonBin $lifecycle cleanup-if-stale --plugin-root $pluginRoot *>$null

    exit $routeRc
} catch {
    # フェイルオープン
    exit 0
}
