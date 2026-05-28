# tests/parity/_smoke/scripts/echo_args.ps1
# 引数を 1 行ずつ stdout に出力。stderr に "[args] count=N" を出す。
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
[Console]::Out.NewLine = "`n"
[Console]::Error.NewLine = "`n"
$count = if ($Args) { $Args.Count } else { 0 }
[Console]::Error.WriteLine("[args] count=$count")
if ($Args) {
    foreach ($a in $Args) {
        [Console]::Out.WriteLine($a)
    }
}
exit 0
