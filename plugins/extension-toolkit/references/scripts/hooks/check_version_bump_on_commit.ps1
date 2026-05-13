# check_version_bump_on_commit.ps1 - PreToolUse Bash フック (PowerShell 7+ 版、ADR-027)
#
# 目的:
#   `git commit ...` 直前に check_version_bump.ps1 を呼び出し、
#   バージョン未更新のプラグインがある場合は警告する。
#
# 入力:
#   stdin: PreToolUse Bash JSON
#
# 出力:
#   - git commit 以外の Bash 呼び出し: exit 0、無音
#   - git commit かつ全プラグインで version 更新済み: exit 0、無音
#   - git commit かつ version 未更新あり: exit 0 + stderr に警告 (fail-open)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $payload = $null
    try {
        $payload = $stdin | ConvertFrom-Json -ErrorAction Stop
    } catch {
        exit 0
    }

    if (-not $payload -or $payload.tool_name -ne 'Bash') { exit 0 }

    $cmd = ''
    if ($payload.tool_input -and $payload.tool_input.PSObject.Properties['command']) {
        $cmd = [string]$payload.tool_input.command
    }
    if ([string]::IsNullOrEmpty($cmd)) { exit 0 }

    if ($cmd -notmatch 'git\s+commit') { exit 0 }

    $scriptDir = Split-Path -Parent $PSCommandPath
    $delegate = Join-Path $scriptDir 'check_version_bump.ps1'
    if (-not (Test-Path -LiteralPath $delegate -PathType Leaf)) { exit 0 }

    # 委譲スクリプトに空 JSON を渡す (check_version_bump.ps1 は stdin を読み捨てる)
    '{}' | & pwsh -NoProfile -File $delegate
} catch {
    # フェイルオープン
}

exit 0
