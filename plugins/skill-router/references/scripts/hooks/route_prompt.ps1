# route_prompt.ps1 - UserPromptSubmit hook for skill-router (PowerShell 版)
#
#
# CRITICAL: stdin JSON は PowerShell で parse せず、Python (json.load) に委譲する。
# PowerShell の責務は: Python interpreter の起動 / toggle (disabled) check / stdin の素通し のみ。
#
# Fail-open: any error must not block the user prompt.

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# --- Read stdin payload first ---
$stdinPayload = [Console]::In.ReadToEnd()

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

# --- Toggle check (inline from resolve_base.sh) ---

function Get-SkillRouterHomeDir {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($env:HOME) { return $env:HOME }
    return $null
}

function Get-SkillRouterProjectRoot {
    param([string]$StartDir = (Get-Location).Path)
    $dir = $StartDir
    $homeDir = Get-SkillRouterHomeDir
    if ($homeDir) { $homeDir = $homeDir.TrimEnd('\', '/') }

    while ($dir) {
        $trimmed = $dir.TrimEnd('\', '/')
        if (-not $trimmed -or $trimmed -eq '.') { return $null }
        if (Test-Path (Join-Path $dir '.git') -ErrorAction SilentlyContinue) { return $dir }
        if ($homeDir -and $trimmed -eq $homeDir) { return $null }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { return $null }
        $dir = $parent
    }
    return $null
}

# Check CLAUDE_PLUGIN_DATA/disabled
if ($env:CLAUDE_PLUGIN_DATA -and (Test-Path (Join-Path $env:CLAUDE_PLUGIN_DATA 'disabled') -ErrorAction SilentlyContinue)) {
    exit 0
}

# Check repo-level disabled
$repo = Get-SkillRouterProjectRoot
if ($repo -and (Test-Path (Join-Path $repo '.claude/.local/plugins/skill-router/disabled') -ErrorAction SilentlyContinue)) {
    exit 0
}

# Check home-level disabled
$homeDir = Get-SkillRouterHomeDir
if ($homeDir -and (Test-Path (Join-Path $homeDir '.claude/.local/plugins/skill-router/disabled') -ErrorAction SilentlyContinue)) {
    exit 0
}

# --- Get venv python ---
$lifecycle = Join-Path $pluginRoot 'references/scripts/lib/venv_lifecycle.py'
$venvPy = & $pythonBin $lifecycle 'python-bin' '--plugin-root' $pluginRoot '--no-construct' 2>$null
if (-not $venvPy -or ($venvPy -replace '\s','') -eq '') { $venvPy = $pythonBin }

$routeScript = Join-Path $pluginRoot 'references/scripts/lib/route.py'

# --- Pass stdin to Python route script via .NET Process API ---
# Using System.Diagnostics.Process to pipe stdin reliably (pwsh pipe encoding issues).
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $venvPy
$psi.Arguments = "`"$routeScript`""
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
$psi.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
$psi.CreateNoWindow = $true

$routeRc = 0
try {
    $proc = [System.Diagnostics.Process]::Start($psi)

    # Write stdin payload and close
    if ($stdinPayload) {
        $proc.StandardInput.Write($stdinPayload)
    }
    $proc.StandardInput.Close()

    # Read stdout/stderr
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $routeRc = $proc.ExitCode

    # Forward stdout (this is the hook JSON output)
    if ($stdout) { Write-Output $stdout }
    # Forward stderr
    if ($stderr) { [Console]::Error.Write($stderr) }
} catch {
    $routeRc = 1
}

# --- Stale-venv teardown (routing 完了後) ---
& $pythonBin $lifecycle 'cleanup-if-stale' '--plugin-root' $pluginRoot 2>&1 | Out-Null

exit $routeRc
