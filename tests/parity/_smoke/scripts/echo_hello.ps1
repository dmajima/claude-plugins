# tests/parity/_smoke/scripts/echo_hello.ps1
# Bash 版 echo_hello.sh と等価の出力を返す。
[Console]::Out.NewLine = "`n"
[Console]::Out.WriteLine("hello world")
exit 0
