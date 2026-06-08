# toggle.ps1 - Toggle skill-router routing on/off (PowerShell 7+ 版).
#
# Usage:
#   pwsh -NoProfile -File toggle.ps1 status   # print "skill-router: ON" or "skill-router: OFF"
#   pwsh -NoProfile -File toggle.ps1 off      # create disabled flag at the highest-priority writable base
#   pwsh -NoProfile -File toggle.ps1 on       # remove disabled flag from every layer where it exists

param(
    [Parameter(Position = 0)]
    [string]$Action = 'status'
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'resolve_base.ps1')

$pluginData = $env:CLAUDE_PLUGIN_DATA
$homeDir = Get-SkillRouterHomeDir
$homeBase = if ($homeDir) { Join-Path $homeDir '.claude/.local/plugins/skill-router' } else { '' }

$repoBase = ''
$repo = Get-SkillRouterProjectRoot
if ($repo) {
    $repoBase = Join-Path $repo '.claude/.local/plugins/skill-router'
}

function Test-DisabledFlag {
    param([string]$BasePath)
    if ([string]::IsNullOrEmpty($BasePath)) { return $false }
    return Test-Path -LiteralPath (Join-Path $BasePath 'disabled') -PathType Leaf
}

function Invoke-Status {
    if ((Test-DisabledFlag $pluginData) -or
        (Test-DisabledFlag $repoBase) -or
        (Test-DisabledFlag $homeBase)) {
        Write-Output 'skill-router: OFF'
    } else {
        Write-Output 'skill-router: ON'
    }
}

function Invoke-Off {
    $base = Get-SkillRouterBase
    if (-not $base) {
        Write-Output 'skill-router: failed to resolve base directory'
        return
    }
    try {
        New-Item -ItemType Directory -Force -Path $base -ErrorAction Stop | Out-Null
        $flagPath = Join-Path $base 'disabled'
        if (-not (Test-Path -LiteralPath $flagPath -PathType Leaf)) {
            New-Item -ItemType File -Force -Path $flagPath -ErrorAction Stop | Out-Null
        } else {
            # Touch: update timestamp
            (Get-Item -LiteralPath $flagPath).LastWriteTime = Get-Date
        }
        Write-Output "skill-router toggled OFF (flag: $base/disabled)"
    } catch {
        Write-Output "skill-router: failed to write disabled flag at $base/disabled ($_)"
    }
}

function Invoke-On {
    $removed = 0
    foreach ($base in @($pluginData, $repoBase, $homeBase)) {
        if ([string]::IsNullOrEmpty($base)) { continue }
        $flagPath = Join-Path $base 'disabled'
        if (Test-Path -LiteralPath $flagPath -PathType Leaf) {
            try {
                Remove-Item -LiteralPath $flagPath -Force -ErrorAction Stop
                Write-Output "skill-router: removed disabled flag at $flagPath"
                $removed++
            } catch {
                Write-Output "skill-router: failed to remove disabled flag at $flagPath ($_)"
            }
        }
    }
    Write-Output "skill-router toggled ON (cleared $removed flag(s))"
}

switch ($Action.ToLowerInvariant()) {
    'status' { Invoke-Status }
    'off'    { Invoke-Off }
    'on'     { Invoke-On }
    default  {
        Write-Output "skill-router: unknown action '$Action' (expected: status|on|off)"
    }
}

exit 0
