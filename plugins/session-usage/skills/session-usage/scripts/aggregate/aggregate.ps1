#Requires -Version 7.0
<#
.SYNOPSIS
    Claude Code のセッション JSONL からトークン消費量を集計・整形する。

.DESCRIPTION
    集計結果を整形済み文字列として返却する。表示・コピー等の出力アクションは
    呼び出し元（aggregate コマンドモード or tui.ps1）が担当する。

.PARAMETER SessionId
    対象セッションID。未指定時は $env:CLAUDE_CODE_SESSION_ID、それも無ければ最新mtimeのJSONL。

.PARAMETER ProjectKey
    プロジェクトキー。未指定時は cwd から自動導出。

.PARAMETER AsObject
    指定時は整形済み文字列ではなく集計結果オブジェクトを返す（TUI 等での再描画用途）。

.OUTPUTS
    [string]    既定: 整形済み複数行文字列
    [pscustomobject]  -AsObject 指定時: 集計結果のフィールド一式
#>
[CmdletBinding()]
param(
    [string]$SessionId,
    [string]$ProjectKey,
    [switch]$AsObject,
    [switch]$Stdout,     # Bash 経由から呼ぶ場合はこれを指定して UTF-8 で直接 stdout に書き出す
    [switch]$Copy        # 整形済み文字列をクリップボードへコピーする
)

$ErrorActionPreference = 'Stop'

# pwsh 内部の出力エンコーディングを UTF-8 に固定
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ---- パラメータ解決 ----
if (-not $SessionId)  { $SessionId  = $env:CLAUDE_CODE_SESSION_ID }
if (-not $ProjectKey) { $ProjectKey = (Get-Location).Path -replace '[\\:/]', '-' }

$projectDir = Join-Path $env:USERPROFILE ".claude/projects/$ProjectKey"
if (-not (Test-Path $projectDir)) {
    throw "プロジェクトディレクトリが見つかりません: $projectDir"
}

# ---- JSONL ファイル特定 ----
$jsonlPath = $null
if ($SessionId) {
    $candidate = Join-Path $projectDir "$SessionId.jsonl"
    if (Test-Path $candidate) {
        $jsonlPath = $candidate
    } else {
        throw "指定セッションの JSONL が見つかりません: $candidate"
    }
}
if (-not $jsonlPath) {
    $latest = Get-ChildItem -Path $projectDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) { $jsonlPath = $latest.FullName; $SessionId = $latest.BaseName }
}
if (-not $jsonlPath) {
    throw "セッションログが見つかりません: $projectDir"
}

# ---- JSONL 集計 ----
$totals = [ordered]@{
    msg_count    = [long]0
    input        = [long]0
    cache_create = [long]0
    cache_read   = [long]0
    output       = [long]0
    web_search   = [long]0
    web_fetch    = [long]0
}
$byModel = [ordered]@{}
$firstTs = $null
$lastTs  = $null
$customTitle = $null
$aiTitle = $null

$reader = [System.IO.StreamReader]::new($jsonlPath, [System.Text.Encoding]::UTF8)
try {
    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $obj = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }

        if ($obj.type -eq 'custom-title') {
            if ($null -ne $obj.customTitle) { $customTitle = [string]$obj.customTitle }
            continue
        }
        if ($obj.type -eq 'ai-title') {
            if ($null -ne $obj.aiTitle) { $aiTitle = [string]$obj.aiTitle }
            continue
        }
        if ($obj.type -ne 'assistant') { continue }
        if (-not $obj.message -or -not $obj.message.usage) { continue }

        $u = $obj.message.usage
        $model = if ($obj.message.model) { [string]$obj.message.model } else { 'unknown' }

        $vIn  = if ($null -ne $u.input_tokens)                { [long]$u.input_tokens }                else { 0 }
        $vCC  = if ($null -ne $u.cache_creation_input_tokens) { [long]$u.cache_creation_input_tokens } else { 0 }
        $vCR  = if ($null -ne $u.cache_read_input_tokens)     { [long]$u.cache_read_input_tokens }     else { 0 }
        $vOut = if ($null -ne $u.output_tokens)               { [long]$u.output_tokens }               else { 0 }

        $totals.msg_count    += 1
        $totals.input        += $vIn
        $totals.cache_create += $vCC
        $totals.cache_read   += $vCR
        $totals.output       += $vOut

        if ($u.server_tool_use) {
            if ($null -ne $u.server_tool_use.web_search_requests) { $totals.web_search += [long]$u.server_tool_use.web_search_requests }
            if ($null -ne $u.server_tool_use.web_fetch_requests)  { $totals.web_fetch  += [long]$u.server_tool_use.web_fetch_requests }
        }

        if (-not $byModel.Contains($model)) {
            $byModel[$model] = [ordered]@{ count = [long]0; total = [long]0 }
        }
        $byModel[$model].count += 1
        $byModel[$model].total += ($vIn + $vCC + $vCR + $vOut)

        if ($obj.timestamp) {
            if (-not $firstTs) { $firstTs = $obj.timestamp }
            $lastTs = $obj.timestamp
        }
    }
} finally {
    $reader.Dispose()
}

$grandTotal = $totals.input + $totals.cache_create + $totals.cache_read + $totals.output

$sessionName = if ($customTitle) { "$customTitle (renamed)" }
               elseif ($aiTitle) { "$aiTitle (auto)" }
               else { '(unnamed)' }

$periodStr = ''
if ($firstTs -and $lastTs) {
    try {
        $start = [datetime]::Parse($firstTs).ToLocalTime()
        $end   = [datetime]::Parse($lastTs).ToLocalTime()
        $dur   = $end - $start
        $durStr = if ($dur.TotalHours -ge 1) { '{0:N1} h' -f $dur.TotalHours } else { '{0:N0} min' -f $dur.TotalMinutes }
        $periodStr = '{0:yyyy-MM-dd HH:mm} - {1:HH:mm}  ({2})' -f $start, $end, $durStr
    } catch { $periodStr = "$firstTs - $lastTs" }
}

# ---- AsObject モード ----
if ($AsObject) {
    return [pscustomobject]@{
        SessionId    = $SessionId
        SessionName  = $sessionName
        Period       = $periodStr
        JsonlPath    = $jsonlPath
        Totals       = $totals
        ByModel      = $byModel
        GrandTotal   = $grandTotal
        Generated    = (Get-Date)
    }
}

# ---- 整形済み文字列モード ----
function Format-KP([long]$n, [long]$total) {
    $pct = if ($total -gt 0) { ($n / [double]$total) * 100 } else { 0 }
    '{0,9:N1}k ({1,5:N1}%)' -f ($n / 1000.0), $pct
}
function Format-K([long]$n) { '{0,9:N1}k' -f ($n / 1000.0) }

# preview の monospace box 幅に収まるよう全行を WIDTH 以内に統一する
$WIDTH = 40
$double = '=' * $WIDTH
$single = '-' * $WIDTH

# 全角は 2 幅、それ以外は 1 幅で計算
function Get-DisplayWidth([string]$s) {
    $w = 0
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        if ($code -ge 0x1100 -and ($code -le 0x115F -or $code -ge 0x2E80)) { $w += 2 } else { $w += 1 }
    }
    return $w
}

# 任意の行を WIDTH 幅で折り返す（続行行は元の行のインデントを継承）
function Wrap-Line([string]$Line) {
    if ((Get-DisplayWidth $Line) -le $WIDTH) {
        return ,$Line
    }
    # 行頭の連続スペースをインデントとして継承
    $indent = ''
    foreach ($ch in $Line.ToCharArray()) {
        if ($ch -eq ' ') { $indent += ' ' } else { break }
    }
    $indentW = Get-DisplayWidth $indent

    $result = New-Object 'System.Collections.Generic.List[string]'
    $current = ''
    $currentW = 0
    $isFirst = $true
    foreach ($ch in $Line.ToCharArray()) {
        $code = [int]$ch
        $cw = if ($code -ge 0x1100 -and ($code -le 0x115F -or $code -ge 0x2E80)) { 2 } else { 1 }
        if ($currentW + $cw -gt $WIDTH) {
            $result.Add($current)
            $current = $indent
            $currentW = $indentW
            $isFirst = $false
        }
        $current += $ch
        $currentW += $cw
    }
    if ($current.Length -gt 0) {
        $result.Add($current)
    }
    return $result
}

$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add('')
$lines.Add($double)
$lines.Add('  Claude Code  Session Usage')
$lines.Add($double)
$lines.Add(("  Session  : {0}" -f $sessionName))
$lines.Add(("  ID       : {0}" -f $SessionId))
if ($periodStr) { $lines.Add(("  Period   : {0}" -f $periodStr)) }
$lines.Add(("  Requests : {0:N0}" -f $totals.msg_count))
$lines.Add('')
$lines.Add('  -- Token Consumption ' + ('-' * 17))
$lines.Add(("  Input          : {0}" -f (Format-KP $totals.input        $grandTotal)))
$lines.Add(("  Cache Creation : {0}" -f (Format-KP $totals.cache_create $grandTotal)))
$lines.Add(("  Cache Read     : {0}" -f (Format-KP $totals.cache_read   $grandTotal)))
$lines.Add(("  Output         : {0}" -f (Format-KP $totals.output       $grandTotal)))
$lines.Add('  ' + ('-' * ($WIDTH - 2)))
$lines.Add(("  Total          : {0}" -f (Format-K  $grandTotal)))

# Per-Model: モデル名と値を 2 行に分割（長いモデル名は折り返しヘルパーが処理）
$lines.Add('')
$lines.Add('  -- Per-Model ' + ('-' * 25))
foreach ($k in $byModel.Keys) {
    $b = $byModel[$k]
    $lines.Add(("  {0}" -f $k))
    $lines.Add(("      {0} / {1:N0} calls" -f (Format-K $b.total), $b.count))
}

# Server Tools: 0 でない場合のみ
if ($totals.web_search -gt 0 -or $totals.web_fetch -gt 0) {
    $lines.Add('')
    $lines.Add('  -- Server Tools ' + ('-' * 22))
    if ($totals.web_search -gt 0) { $lines.Add(("  Web Search Requests : {0,8:N0}" -f $totals.web_search)) }
    if ($totals.web_fetch  -gt 0) { $lines.Add(("  Web Fetch  Requests : {0,8:N0}" -f $totals.web_fetch))  }
}

$lines.Add('')
$lines.Add($double)

# 全行を WIDTH で折り返し（保険）
$wrapped = New-Object 'System.Collections.Generic.List[string]'
foreach ($line in $lines) {
    foreach ($w in (Wrap-Line $line)) {
        $wrapped.Add($w)
    }
}
$lines = $wrapped

$rendered = $lines -join [Environment]::NewLine

# UTF-8 で stdout に直接書き出すヘルパー（Bash 経由でも文字化けしない）
function Write-Utf8Stdout([string]$Text) {
    $utf8   = [System.Text.UTF8Encoding]::new($false)
    $bytes  = $utf8.GetBytes($Text + [Environment]::NewLine)
    $stream = [Console]::OpenStandardOutput()
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
}

# クリップボードコピー（要求時のみ。スキル本体からは自動付与されない）
$copyResult = $null
if ($Copy) {
    try {
        $rendered | Set-Clipboard
        $copyResult = '  [OK] clipboard へコピーしました'
    } catch {
        $copyResult = "  [NG] Set-Clipboard failed: $($_.Exception.Message)"
    }
}

# 出力モード分岐
if ($Stdout -and $Copy) {
    # 表示 + コピー（直接実行・テスト用途）
    Write-Utf8Stdout $rendered
    Write-Utf8Stdout $copyResult
    return
}

if ($Stdout) {
    # 表示のみ（スキル本体のメインフロー）
    Write-Utf8Stdout $rendered
    return
}

if ($Copy) {
    # コピーのみ（AskUserQuestion で「クリップボードへコピー」が選ばれた場合）
    Write-Utf8Stdout $copyResult
    return
}

# 既定: 文字列を返す（PowerShell 内部呼び出し用）
return $rendered
