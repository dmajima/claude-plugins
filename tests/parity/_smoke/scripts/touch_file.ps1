# tests/parity/_smoke/scripts/touch_file.ps1
# 環境変数 OUT_FILE で指定されたパスに固定内容のファイルを作成する。
[Console]::Out.NewLine = "`n"
$target = $env:OUT_FILE
if (-not $target) {
    [Console]::Error.WriteLine("OUT_FILE not set")
    exit 2
}
$dir = Split-Path -Parent $target
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
# UTF-8 (no BOM) で固定内容を書き出す
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($target, "line1`nline2`n", $utf8)
[Console]::Out.WriteLine("touched: $target")
exit 0
