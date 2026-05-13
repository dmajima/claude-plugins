# setup_venv.ps1 - venv 構築スクリプト (PowerShell 7+ 版、skill-router プラグイン共通)
# ADR-024 / scripts-policy.md 5.2 準拠
#
# 使い方:
#   pwsh -NoProfile -File setup_venv.ps1 -WorkDir <work_dir> [-RequirementsPath <path>] [-MinPythonVersion <X.Y>]
#
# 役割分担:
#   - 本スクリプト: extension-reviewer / 手動テスト / CI 等が `<work_dir>/.venv` を
#     構築する用途のための *オーケストレータ向け汎用 venv 構築*。
#   - 内蔵 venv ライフサイクル管理 (`references/scripts/lib/venv_lifecycle.py`):
#     ランタイム (SessionStart / UserPromptSubmit フック) が `<base>/.venv` を
#     動的に管理 (72h TTL / 1 セッション 3 回までの自動再構築 / fail-open)。

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir,

    [Parameter(Position = 1)]
    [string]$RequirementsPath = '',

    [Parameter(Position = 2)]
    [string]$MinPythonVersion = ''
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($WorkDir)) {
    Write-Error "Usage: pwsh -NoProfile -File setup_venv.ps1 -WorkDir <work_dir> [-RequirementsPath <path>] [-MinPythonVersion <X.Y>]"
    exit 1
}

# 安全装置: WorkDir 正規化と .claude/.local/ 配下チェック
$resolvedWorkDir = [System.IO.Path]::GetFullPath($WorkDir)
$normalizedWorkDir = $resolvedWorkDir -replace '\\', '/'
if ($normalizedWorkDir -notmatch '/\.claude/\.local/') {
    [Console]::Error.WriteLine("[setup_venv] Error: work_dir is not under .claude/.local/, refusing to create venv.")
    [Console]::Error.WriteLine("  target (input): $WorkDir")
    [Console]::Error.WriteLine("  target (normalized): $normalizedWorkDir")
    exit 1
}

$venvDir = Join-Path $WorkDir '.venv'

# Python コマンド検出
$pythonCmd = $null
foreach ($candidate in @('python', 'python3', 'py')) {
    try {
        & $candidate -m venv --help *>$null
        if ($LASTEXITCODE -eq 0) {
            $pythonCmd = $candidate
            break
        }
    } catch {}
}
if (-not $pythonCmd) {
    [Console]::Error.WriteLine("[setup_venv] Error: python / python3 / py のいずれでも venv モジュールが利用できません")
    exit 1
}
Write-Host "[setup_venv] Python コマンド: $pythonCmd"

# システム Python のバージョン要件チェック
if (-not [string]::IsNullOrEmpty($MinPythonVersion)) {
    if ($MinPythonVersion -notmatch '^[0-9]+(\.[0-9]+){0,2}$') {
        [Console]::Error.WriteLine("[setup_venv] Error: Invalid MIN_PYTHON_VERSION format: $MinPythonVersion")
        exit 1
    }
    $actualVersion = & $pythonCmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
    if (-not $actualVersion) { $actualVersion = '0.0' }

    $env:MIN_PYTHON_VERSION = $MinPythonVersion
    try {
        $meets = & $pythonCmd -c @'
import os, sys
req = os.environ["MIN_PYTHON_VERSION"].split(".")
cur = (sys.version_info.major, sys.version_info.minor)
req_t = tuple(int(x) for x in req[:2]) if len(req) >= 2 else (int(req[0]), 0)
print("1" if cur >= req_t else "0")
'@
    } finally {
        Remove-Item Env:MIN_PYTHON_VERSION -ErrorAction SilentlyContinue
    }

    if ($meets -ne '1') {
        [Console]::Error.WriteLine("[setup_venv] Error: Python $MinPythonVersion+ required, found $actualVersion.")
        exit 1
    }
    Write-Host "[setup_venv] Python $actualVersion meets requirement (>= $MinPythonVersion)"
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

if (Test-Path -LiteralPath $venvDir -PathType Container) {
    Write-Host "[setup_venv] venv already exists at $venvDir, reusing"
} else {
    Write-Host "[setup_venv] Creating venv at $venvDir"
    & $pythonCmd -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("[setup_venv] Error: venv creation failed")
        exit 1
    }
}

# Python binary in venv
$python = $null
$candidates = @(
    (Join-Path $venvDir 'Scripts/python.exe'),
    (Join-Path $venvDir 'Scripts/python'),
    (Join-Path $venvDir 'bin/python')
)
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c -PathType Leaf) {
        $python = $c
        break
    }
}
if (-not $python) {
    [Console]::Error.WriteLine("[setup_venv] Error: Python binary not found in venv")
    exit 1
}

Write-Host "[setup_venv] Upgrading pip / setuptools / wheel"
& $python -m pip install --upgrade pip setuptools wheel
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("[setup_venv] Error: pip upgrade failed")
    exit 1
}

if (-not [string]::IsNullOrEmpty($RequirementsPath)) {
    if (Test-Path -LiteralPath $RequirementsPath -PathType Leaf) {
        Write-Host "[setup_venv] Installing requirements from $RequirementsPath"
        & $python -m pip install -r $RequirementsPath
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("[setup_venv] Error: requirements install failed")
            exit 1
        }
    } else {
        [Console]::Error.WriteLine("[setup_venv] Warning: $RequirementsPath not found, skipping")
    }
}

Write-Host "[setup_venv] Ready: $venvDir"
$pythonVersion = & $python --version 2>&1
Write-Host "[setup_venv] Python: $pythonVersion"
