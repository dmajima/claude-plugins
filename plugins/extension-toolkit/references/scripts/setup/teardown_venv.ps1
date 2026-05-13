# teardown_venv.ps1 - venv 撤去スクリプト (PowerShell 7+ 版、プラグイン横断)
#
# 使い方: pwsh -NoProfile -File teardown_venv.ps1 -WorkDir <work_dir>
#   <work_dir>/.venv を削除する

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

# 安全装置 1: パスを正規化 (シンボリックリンク迂回を防ぐ)
try {
    $resolvedVenvDir = [System.IO.Path]::GetFullPath($venvDir)
} catch {
    [Console]::Error.WriteLine("[teardown_venv] Error: path resolution failed, refusing to delete.")
    [Console]::Error.WriteLine("  target (input): $venvDir")
    exit 1
}

# シンボリックリンク先を解決 (リンクの場合)
if (Test-Path -LiteralPath $resolvedVenvDir) {
    try {
        $item = Get-Item -LiteralPath $resolvedVenvDir -Force
        if ($item.PSObject.Properties['Target'] -and $item.Target) {
            $resolvedVenvDir = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $resolvedVenvDir) $item.Target))
        }
    } catch {}
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

# 安全装置 3: システムルートパスを禁止 (二重チェック)
$systemRoots = @(
    '^/$',
    '^/root($|/)',
    '^/home($|/)',
    '^/etc($|/)',
    '^/usr($|/)',
    '^/var($|/)',
    '^/bin($|/)',
    '^/sbin($|/)',
    '^/opt($|/)',
    '^/Users($|/)',
    '^[A-Za-z]:/$'
)
foreach ($pattern in $systemRoots) {
    if ($normalizedPath -match $pattern) {
        # .claude/.local/ を含むため上記で許容済みのケースは安全装置 2 で通過
        if ($normalizedPath -notmatch '/\.claude/\.local/') {
            [Console]::Error.WriteLine("[teardown_venv] Error: refusing to operate on system path: $normalizedPath")
            exit 1
        }
    }
}

if (Test-Path -LiteralPath $venvDir -PathType Container) {
    Remove-Item -Recurse -Force -LiteralPath $venvDir
    Write-Host "[teardown_venv] Removed $venvDir"
} else {
    Write-Host "[teardown_venv] No venv at $venvDir, nothing to do"
}
