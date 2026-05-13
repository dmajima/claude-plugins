# setup_venv.ps1 - convert-doc プラグイン共通 venv 構築スクリプト (PowerShell 7+ 版、ADR-024 準拠)
#
# 使い方:
#   pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.ps1" -WorkDir <WORK_DIR>
#
# 引数:
#   -WorkDir  venv を作成するワークディレクトリのパス (通常はセッションの workspace/ 配下)
#             例: .claude/.local/work/20260512_01_convert_doc/workspace

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($WorkDir)) {
    [Console]::Error.WriteLine("エラー: WorkDir を第1引数に指定してください。例: -WorkDir .claude/.local/work/(session)/workspace")
    exit 1
}

$scriptDir = Split-Path -Parent $PSCommandPath
$venvDir = Join-Path $WorkDir '.venv'
$requirements = Join-Path $scriptDir 'requirements.txt'

if (-not (Test-Path -LiteralPath $requirements -PathType Leaf)) {
    [Console]::Error.WriteLine("エラー: requirements.txt が見つかりません: $requirements")
    exit 1
}

$venvPython = $null
$venvCandidates = @(
    (Join-Path $venvDir 'Scripts/python.exe'),
    (Join-Path $venvDir 'Scripts/python'),
    (Join-Path $venvDir 'bin/python')
)
foreach ($c in $venvCandidates) {
    if (Test-Path -LiteralPath $c -PathType Leaf) {
        $venvPython = $c
        break
    }
}

if ($venvPython) {
    Write-Host "venv が既に存在します。再利用します: $venvDir"
} else {
    Write-Host "venv を作成しています: $venvDir"
    & python -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("エラー: venv 作成に失敗しました")
        exit 1
    }
    foreach ($c in $venvCandidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) {
            $venvPython = $c
            break
        }
    }
}

if (-not $venvPython) {
    [Console]::Error.WriteLine("エラー: venv 内に Python バイナリが見つかりません: $venvDir")
    exit 1
}

# pip パス
$pip = $null
$pipCandidates = @(
    (Join-Path $venvDir 'Scripts/pip.exe'),
    (Join-Path $venvDir 'Scripts/pip'),
    (Join-Path $venvDir 'bin/pip')
)
foreach ($c in $pipCandidates) {
    if (Test-Path -LiteralPath $c -PathType Leaf) {
        $pip = $c
        break
    }
}

Write-Host "パッケージをインストールしています: $requirements"
if ($pip) {
    & $pip install --quiet -r $requirements
} else {
    & $venvPython -m pip install --quiet -r $requirements
}
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("エラー: requirements インストールに失敗しました")
    exit 1
}

Write-Host "完了: $venvDir"
Write-Host "Python: $venvPython"
