# resolve_base.ps1 - Resolve skill-router <base> directory (PowerShell 7+ 版).
#
# Resolution order (kept in lock-step with build_index.resolve_base_dir
# in references/scripts/lib/build_index.py so PowerShell callers and Python
# callers always agree on the same <base>):
#
#   1. ${env:CLAUDE_PLUGIN_DATA}                              (plugin data dir)
#   2. <repo-root>/.claude/.local/plugins/skill-router/       (walk parents
#                                                              from $PWD looking
#                                                              for .git)
#   3. <user-home>/.claude/.local/plugins/skill-router/       (user scope)
#
# Usage:
#   - Dot-source to import functions:
#       . ${env:CLAUDE_PLUGIN_ROOT}/references/scripts/commands/resolve_base.ps1
#   - Direct invocation echoes the resolved base path on stdout:
#       pwsh -NoProfile -File ./resolve_base.ps1

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Get-SkillRouterHomeDir {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($env:HOME) { return $env:HOME }
    return ''
}

function Get-SkillRouterProjectRoot {
    param([string]$Dir = $PWD.Path)

    $homeDir = Get-SkillRouterHomeDir
    if ($homeDir) { $homeDir = $homeDir.TrimEnd('\', '/') }

    while ($Dir) {
        $trimmed = $Dir.TrimEnd('\', '/')
        if ([string]::IsNullOrEmpty($trimmed) -or $trimmed -eq '.') { return $null }

        if (Test-Path -LiteralPath (Join-Path $Dir '.git')) {
            return $Dir
        }

        if ($homeDir -and ($trimmed -eq $homeDir)) {
            return $null
        }

        $parent = Split-Path -Parent $Dir
        if (-not $parent -or $parent -eq $Dir) {
            return $null
        }
        $Dir = $parent
    }
    return $null
}

function Get-SkillRouterBase {
    if ($env:CLAUDE_PLUGIN_DATA) {
        return $env:CLAUDE_PLUGIN_DATA
    }
    $repo = Get-SkillRouterProjectRoot
    if ($repo) {
        return (Join-Path $repo '.claude/.local/plugins/skill-router')
    }
    $homeDir = Get-SkillRouterHomeDir
    if ($homeDir) {
        return (Join-Path $homeDir '.claude/.local/plugins/skill-router')
    }
    return ''
}

# Direct invocation: echo the resolved base. Dot-source: skip echo.
# $MyInvocation.InvocationName is '.' when dot-sourced, otherwise the invocation path.
if ($MyInvocation.InvocationName -ne '.') {
    $base = Get-SkillRouterBase
    if ($base) { Write-Output $base }
}
