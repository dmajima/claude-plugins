#requires -Version 7

<#
.SYNOPSIS
    {skill-name} スキルの代表シナリオを自動デモする再現可能スクリプト
    (B-3: improvement-backlog 由来)

.DESCRIPTION
    A-1 (動作デモ + ユーザ承認フロー必須化) と整合する、セッションを跨いで
    同じデモを再現できるテンプレート。新規スキル作成時にこのファイルを
    skills/{skill-name}/evals/demo.ps1 にコピーし、`{...}` プレースホルダを
    実際のコマンド・期待値で埋める。

    実装方針：
    - 代表的な正常系 (dry-run) を必ず含める
    - 主要分岐 1 件以上を実行 (引数・フラグ違いで挙動が変わる箇所)
    - AskUserQuestion 含有スキルなら「対話モードへの誘導コマンド」を 1 件記載
      （対話 UI そのものは Claude Code セッションでないと発火しないため、
       誘導コマンドの起動確認まで demo.ps1 で扱う）
    - エラーパス (引数不正・前提不足等) を 1 件含める
    - ファイル副作用がある場合は実行前に「これから何が起きるか」を Write-Host で提示
    - 終了時に再現コマンド一覧と「承認確認時の論点」をユーザに提示

.PARAMETER WhatIf
    実コマンドを実行せず、計画のみ表示する (true 既定で副作用ゼロ)。
    実コマンド実行を許可する場合のみ -WhatIf:$false を指定する。

.PARAMETER Workspace
    一時生成物の出力先 (省略時はカレントの .claude/.local/work/demo/ 配下)

.EXAMPLE
    # 計画のみ表示 (副作用ゼロ)
    pwsh -NoProfile -File evals/demo.ps1

.EXAMPLE
    # 実コマンドを実行 (dry-run は副作用なし)
    pwsh -NoProfile -File evals/demo.ps1 -WhatIf:$false

.NOTES
    関連:
    - A-1: completion-checklist.md 節 2.4 (動作デモ + 承認取得)
    - B-2: run_evals.py (このスクリプトは B-2 の runnable: true ケースとして
           登録するか、または開発者向けデモとして別運用するか選択可能)
    - ADR-032: 動作デモ + 承認フロー必須化
#>

param(
    [switch]$WhatIf = $true,
    [string]$Workspace = ".claude/.local/work/demo_{skill-name}"
)

$ErrorActionPreference = 'Stop'
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------------------
# ヘルパ
# ---------------------------------------------------------------------------

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Output ""
    Write-Output "================================================================"
    Write-Output "  $Title"
    Write-Output "================================================================"
}

function Invoke-DemoStep {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Command,
        [string]$ExpectExitCode = "0",
        [switch]$ContinueOnError
    )
    Write-Section "Step: $Name"
    Write-Output "  Command: $Command"
    Write-Output "  Expect exit code: $ExpectExitCode"
    if ($WhatIf) {
        Write-Output "  [WhatIf] スキップ (副作用ゼロモード)"
        return
    }
    try {
        $output = & pwsh -NoProfile -NonInteractive -Command $Command 2>&1
        Write-Output ($output | Out-String).TrimEnd()
        Write-Output ("  exit code: " + $LASTEXITCODE)
        if (-not $ContinueOnError -and $LASTEXITCODE -ne [int]$ExpectExitCode) {
            throw "Unexpected exit code: $LASTEXITCODE (expected $ExpectExitCode)"
        }
    }
    catch {
        Write-Output "  [ERROR] $_"
        if (-not $ContinueOnError) { throw }
    }
}

# ---------------------------------------------------------------------------
# デモシナリオ
# ---------------------------------------------------------------------------

Write-Section "{skill-name} デモ実行開始"
Write-Output "  WhatIf モード: $WhatIf"
Write-Output "  Workspace:     $Workspace"
Write-Output ""
Write-Output "  実施するシナリオ:"
Write-Output "    1. 代表的な正常系 (dry-run)"
Write-Output "    2. 主要分岐の動作確認"
Write-Output "    3. 対話モード誘導 (AskUserQuestion を発火する場合)"
Write-Output "    4. エラーパス確認 (引数不正等)"
Write-Output ""

if (-not $WhatIf) {
    New-Item -ItemType Directory -Force -Path $Workspace | Out-Null
}

# Step 1: 代表的な正常系 (必ず dry-run / --whatif 等の副作用ゼロコマンドを使う)
Invoke-DemoStep `
    -Name "代表的な正常系 (dry-run)" `
    -Command "{ 例: pwsh -NoProfile -File scripts/main.ps1 -DryRun }" `
    -ExpectExitCode "0"

# Step 2: 主要分岐 (引数違いで挙動が変わるブランチを実行)
Invoke-DemoStep `
    -Name "主要分岐 A (例: --scope global)" `
    -Command "{ 例: pwsh -NoProfile -File scripts/main.ps1 -Scope global -DryRun }" `
    -ExpectExitCode "0"

# Step 3: 対話モード誘導 (AskUserQuestion を含むスキルのみ)
Write-Section "Step: 対話モード誘導"
Write-Output "  Claude Code セッションで以下を実行することで、AskUserQuestion 実発火を確認:"
Write-Output ""
Write-Output "    /your-command       # 引数なしで起動 → AskUserQuestion 発火"
Write-Output ""
Write-Output "  (本スクリプトからは UI を直接発火できないため誘導のみ)"

# Step 4: エラーパス (引数不正・前提不足等)
Invoke-DemoStep `
    -Name "エラーパス (例: 不正引数)" `
    -Command "{ 例: pwsh -NoProfile -File scripts/main.ps1 -Scope INVALID }" `
    -ExpectExitCode "1" `
    -ContinueOnError

# ---------------------------------------------------------------------------
# 完了サマリ
# ---------------------------------------------------------------------------

Write-Section "デモ実行完了"
Write-Output ""
Write-Output "  承認確認時の論点 (ユーザに AskUserQuestion で問うべき項目):"
Write-Output "    - 全 Step の標準出力に想定外のエラー/警告がないか"
Write-Output "    - 副作用 (生成ファイル / 設定変更) が想定通りか"
Write-Output "    - 対話モード誘導の UI 表示が読みやすいか"
Write-Output ""
Write-Output "  再現コマンド (この demo.ps1 自体):"
Write-Output ("    pwsh -NoProfile -File evals/demo.ps1 -WhatIf:" + ($WhatIf.ToString()))
Write-Output ""
Write-Output "  ADR-032 に従い、これらの結果を AskUserQuestion で承認してから引き渡しに進むこと。"
