# clear_embedding_cache.ps1 - Clear the skill-router embedding cache (PowerShell 7+ 版).
#
# Usage:
#   pwsh -NoProfile -File clear_embedding_cache.ps1 -Base <base>
#
# Removes only vectors.npz and manifest.json. The models/ subdirectory is
# preserved so that the next SessionStart does not re-download the ONNX model
# (potentially a 120MB transfer).
#
# Exit 0 always (fail-open).

param(
    [Parameter(Position = 0)]
    [string]$Base
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

if ([string]::IsNullOrEmpty($Base)) {
    Write-Output 'skill-router: <base> argument required for clear_embedding_cache.ps1'
    exit 0
}

$cacheDir = Join-Path $Base 'embeddings_cache'
$targets = @('vectors.npz', 'manifest.json')
foreach ($file in $targets) {
    $path = Join-Path $cacheDir $file
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
        } catch {
            # フェイルオープン
        }
    }
}

Write-Output "skill-router: embedding cache cleared at $cacheDir/"
Write-Output '次回 SessionStart で再生成されます (embedding.enabled=true 時のみ)。'

exit 0
