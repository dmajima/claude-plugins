# check_version_bump_on_commit.ps1 - PreToolUse hook (PowerShell version)
#
#
# `git commit ...` 直前に check_version_bump.ps1 を呼び出し、
# バージョン未更新のプラグインがある場合は警告する。
# 設計: フェイルオープン

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# stdin を読み取り
$stdinData = ''
try { $stdinData = [Console]::In.ReadToEnd() } catch {}
if ([string]::IsNullOrWhiteSpace($stdinData)) { exit 0 }

try {
    $input_obj = $stdinData | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}

$toolName = $input_obj.tool_name
if ($toolName -ne 'Bash') { exit 0 }

$cmd = $input_obj.tool_input.command
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

if ($cmd -notmatch 'git\s+commit') { exit 0 }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$delegate = Join-Path $scriptDir 'check_version_bump.ps1'
if (-not (Test-Path $delegate)) { exit 0 }

# 委譲スクリプトに空 JSON を渡す (stdin 経由)
try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'pwsh'
    $psi.Arguments = "-NoProfile -File `"$delegate`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Write('{}')
    $proc.StandardInput.Close()

    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit(30000) | Out-Null

    $stderrText = $stderrTask.Result
    if ($stderrText) {
        [Console]::Error.Write($stderrText)
    }
} catch {}

exit 0
