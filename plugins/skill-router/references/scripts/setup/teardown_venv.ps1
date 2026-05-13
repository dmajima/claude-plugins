# teardown_venv.ps1 - venv 撤去スクリプト (PowerShell 7+ 版、skill-router プラグイン共通、ADR-024 準拠)
#
# 使い方: pwsh -NoProfile -File teardown_venv.ps1 -WorkDir <work_dir>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($WorkDir)) {
    Write-Error "Usage: pwsh -NoProfile -File teardown_venv.ps1 -WorkDir <work_dir>"
    exit 1
}

$venvDir = Join-Path $WorkDir '.venv'

# 安全装置 1: パス正規化
try {
    $resolvedVenvDir = [System.IO.Path]::GetFullPath($venvDir)
} catch {
    [Console]::Error.WriteLine("[teardown_venv] Error: path resolution failed, refusing to delete.")
    [Console]::Error.WriteLine("  target (input): $venvDir")
    exit 1
}

$normalizedPath = $resolvedVenvDir -replace '\\', '/'

# 安全装置 2: .claude/.local/ 配下のみ削除を許可
if ($normalizedPath -notmatch '/\.claude/\.local/') {
    [Console]::Error.WriteLine("[teardown_venv] Error: venv path is not under .claude/.local/, refusing to delete.")
    [Console]::Error.WriteLine("  target (input): $venvDir")
    [Console]::Error.WriteLine("  target (resolved): $resolvedVenvDir")
    [Console]::Error.WriteLine("  target (normalized): $normalizedPath")
    exit 1
}

if (Test-Path -LiteralPath $venvDir -PathType Container) {
    Remove-Item -Recurse -Force -LiteralPath $venvDir
    Write-Host "[teardown_venv] Removed $venvDir"
} else {
    Write-Host "[teardown_venv] No venv at $venvDir, nothing to do"
}
