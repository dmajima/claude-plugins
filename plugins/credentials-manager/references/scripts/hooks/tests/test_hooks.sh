#!/usr/bin/env bash
# test_hooks.sh
#
# credentials-manager の PreToolUse フック（preempt_credentials_check.sh）と、
# hooks.json の PreToolUse 登録の回帰テスト。実際のフック入力 JSON を流し、
# 通知の有無・理由文・出力の形式・所要時間を検証する。
#
# 実行: bash references/scripts/hooks/tests/test_hooks.sh [検証するスクリプト]
#   引数を省略するとプラグイン同梱の preempt_credentials_check.sh を検証する
#   Windows では Git Bash で実行する（PowerShell から呼ぶ場合、PATH 上の bash は WSL に解決されることがある）
# 前提: bash と jq（jq が無いとフックは常に何も出力せず、不具合と区別できないため中断する）
# 終了コード: 0 = 全件 PASS、1 = FAIL あり、2 = 前提を満たさない
#
# 対象のツール名は hooks.json の matcher とスクリプトの case 分岐の 2 か所にあり、片方だけでは検査が働かない。
# そのため matcher の一致と、分岐ごとの通知の両方を検証する。
# 「既知の制約」は現在の挙動を記録するもので、合否に含めない（挙動が変わったら [CHANGED] と表示する）。
# 秘密情報らしいダミー値は実行時に組み立てる。このファイルやコマンド文字列に直書きすると、
# 編集・実行するセッションのフック自体が反応するため。

set -u
# Git Bash は、Windows 用の実行ファイル（jq.exe 等）に渡す引数のうち / で始まるものをパスに書き換える。
# テストの入力（/usr/bin/curl ... 等）が書き換わらないよう、変換を止める
export MSYS_NO_PATHCONV=1

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$(cd "$HOOKS/../../.." && pwd)"
TARGET="${1:-$HOOKS/preempt_credentials_check.sh}"
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
SHELL_BIN="${BASH:-bash}"   # フックはテストと同じ bash で起動する

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq が見つかりません（フックは jq が無いと何も出力しないため検証できません）"
  exit 2
fi
if [[ ! -f "$TARGET" || ! -f "$HOOKS_JSON" ]]; then
  echo "ERROR: 検証対象が見つかりません: $TARGET / $HOOKS_JSON"
  exit 2
fi

pad24="$(printf '%24s' '')"
fake_sk="sk-${pad24// /x}"
fake_ghp="ghp_${pad24// /z}"
fake_bearer="Bearer ${pad24// /y}"
CLI_NAMES=(curl wget http httpie aria2c scp sftp ssh rsync gh az aws gcloud kubectl doctl heroku firebase vercel netlify
  docker podman psql mysql mongosh mongo redis-cli terraform tofu ansible ansible-playbook helm pulumi packer vault op bw)
CRED_KW=(TOKEN KEY SECRET PASSWORD PASSWD API AUTH CREDENTIAL SESSION BEARER PRIVATE)

pass=0
fail=0
known=0
changed=0
record() {  # $1=PASS|FAIL $2=表示
  if [[ $1 == PASS ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
  printf '  [%s] %s\n' "$1" "$2"
}

now_ms() {
  if [[ -n ${EPOCHREALTIME-} ]]; then
    local t=${EPOCHREALTIME/[.,]/}
    printf '%s' "${t:0:${#t}-3}"
  else
    printf '%s' "$(($(date +%s) * 1000))"
  fi
}

# フックを起動し、additionalContext を返す（通知なしなら空）。
# 終了コードが 0 以外なら "EXIT=<n>"、出力が約束どおりの JSON でなければ "INVALID_OUTPUT" を返す
judge() {  # $1=フック入力 JSON
  local out rc ctx
  out="$(printf '%s' "$1" | "$SHELL_BIN" "$TARGET" 2>/dev/null)"
  rc=$?
  if [[ $rc -ne 0 ]]; then printf 'EXIT=%s' "$rc"; return; fi
  [[ $out =~ [^[:space:]] ]] || return
  # continue は必ず true（false だとツール呼び出しが止まる）。通知文は PreToolUse の additionalContext に入れる
  if ! ctx="$(printf '%s' "$out" | jq -er 'select(.continue == true and .hookSpecificOutput.hookEventName == "PreToolUse") | .hookSpecificOutput.additionalContext' 2>/dev/null)"; then
    printf 'INVALID_OUTPUT'
    return
  fi
  printf '%s' "$ctx" | tr -d '\r'
}

want=""   # 通知の理由文に含まれるべき語（空なら照合しない）。群・ケースの前で設定する
run() {  # $1=期待(hit|miss) $2=ツール $3=フック入力 JSON $4=表示名
  local exp=$1 tool=$2 json=$3 label=$4 ctx reason
  ctx="$(judge "$json")"
  case "$ctx" in
    EXIT=*|INVALID_OUTPUT)
      record FAIL "$label （フックの出力が異常: $ctx）"
      return
      ;;
  esac
  reason="${ctx#\[credentials-manager\] }"
  reason="${reason%%。*}"
  if [[ $exp == miss ]]; then
    if [[ -z $ctx ]]; then
      record PASS "$label"
    else
      record FAIL "$label （期待: 通知なし / 実際: $reason）"
    fi
    return
  fi
  if [[ -z $ctx ]]; then
    record FAIL "$label （期待: 通知あり / 実際: 通知なし）"
  elif [[ $ctx != *credentials-reader* || $ctx != *マスク* ]]; then
    record FAIL "$label （通知文に credentials-reader の起動指示かマスクの指示が無い）"
  elif [[ ($tool == Bash || $tool == PowerShell) && $reason != "$tool"* ]]; then
    # シェル系の理由文は呼び出し元のツール名で始まる（Bash 固定の文言に戻る退行を検出する）
    record FAIL "$label （理由文が $tool で始まらない: $reason）"
  elif [[ -n $want && $reason != *"$want"* ]]; then
    record FAIL "$label （理由文に「$want」が無い: $reason）"
  else
    record PASS "$label → $reason"
  fi
}

shell_json() {  # $1=ツール $2=コマンド
  jq -cn --arg t "$1" --arg c "$2" '{tool_name: $t, tool_input: {command: $c}}' | tr -d '\r'
}

# シェル系ツールの入力を組み立てて検証する
t() {  # $1=期待 $2=ツール $3=コマンド [$4=表示名]
  run "$1" "$2" "$(shell_json "$2" "$3")" "${4:-$2: $3}"
}

# 既知の制約を記録する（合否に含めない）
tk() {  # $1=現在の挙動(hit|miss) $2=ツール $3=コマンド $4=表示名
  local ctx now
  ctx="$(judge "$(shell_json "$2" "$3")")"
  case "$ctx" in
    EXIT=*|INVALID_OUTPUT)
      record FAIL "$4 （フックの出力が異常: $ctx）"
      return
      ;;
  esac
  if [[ -n $ctx ]]; then now=hit; else now=miss; fi
  known=$((known + 1))
  if [[ $now == "$1" ]]; then
    printf '  [KNOWN] %s（現在: %s）\n' "$4" "$now"
  else
    changed=$((changed + 1))
    printf '  [CHANGED] %s（記録: %s / 現在: %s。意図した変更なら記録を更新する）\n' "$4" "$1" "$now"
  fi
}

echo "=== 1. hooks.json の PreToolUse 登録 ==="
entry="$(jq -c '[.hooks.PreToolUse[]? | select(any(.hooks[]?; (.command // "") | test("preempt_credentials_check\\.sh")))][0] // empty' < "$HOOKS_JSON" | tr -d '\r')"
if [[ -z $entry ]]; then
  record FAIL "PreToolUse に preempt_credentials_check.sh の登録が無い"
else
  matcher="$(printf '%s' "$entry" | jq -r '.matcher // empty' | tr -d '\r')"
  for tool in WebFetch WebSearch Bash PowerShell Read Write Edit MultiEdit NotebookEdit mcp__github__get_me; do
    if [[ $tool =~ ^($matcher)$ ]]; then
      record PASS "matcher が $tool に一致する"
    else
      record FAIL "matcher が $tool に一致しない（matcher: $matcher）"
    fi
  done
  # 処理対象でないツールには一致しない（全ツールに広げると、すべての呼び出しで bash と jq が起動する）
  for tool in AskUserQuestion Agent; do
    if [[ $tool =~ ^($matcher)$ ]]; then
      record FAIL "matcher が処理対象外の $tool にも一致する（matcher: $matcher）"
    else
      record PASS "matcher が処理対象外の $tool に一致しない"
    fi
  done
  hook_def="$(printf '%s' "$entry" | jq -c '.hooks[] | select((.command // "") | test("preempt_credentials_check\\.sh"))' | tr -d '\r')"
  hook_cmd="$(printf '%s' "$hook_def" | jq -r '.command' | tr -d '\r')"
  if [[ $hook_cmd =~ \$\{CLAUDE_PLUGIN_ROOT\}/([^\"]+) && -f "$PLUGIN_ROOT/${BASH_REMATCH[1]}" ]]; then
    record PASS "command が同梱のスクリプトを指す（${BASH_REMATCH[1]}）"
  else
    record FAIL "command が同梱のスクリプトを指していない: $hook_cmd"
  fi
  if [[ "$(printf '%s' "$hook_def" | jq -r '.shell // empty' | tr -d '\r')" == bash ]]; then
    record PASS 'shell が "bash"'
  else
    record FAIL 'shell が "bash" でない'
  fi
  timeout_sec="$(printf '%s' "$hook_def" | jq -r '.timeout // empty' | tr -d '\r')"
  if [[ $timeout_sec =~ ^[0-9]+$ ]]; then
    record PASS "timeout が指定されている（${timeout_sec} 秒）"
  else
    record FAIL "timeout が未指定（既定の 60 秒になる）"
  fi
fi

echo "=== 2. 陽性対照（これが通知されない場合は以降の結果も疑う） ==="
want='外部通信'
t hit Bash 'curl https://api.example.com/v1/users'

echo "=== 3. PowerShell: 外部通信（case-32〜34） ==="
want='外部通信'
t hit PowerShell 'Invoke-RestMethod -Uri https://api.example.com/v1/users'
t hit PowerShell 'Invoke-WebRequest -Uri https://example.com/a.zip -OutFile a.zip'
t hit PowerShell 'invoke-restmethod https://api.example.com/v1/users'
t hit PowerShell 'irm https://api.example.com/v1/users'
t hit PowerShell 'iwr https://api.example.com/v1/users -OutFile a.json'
t hit PowerShell '$r=irm https://api.example.com/v1/users'
t hit PowerShell '$r=iwr https://example.com/a.zip'
t hit PowerShell 'Invoke-Command -ScriptBlock {irm https://api.example.com}'
t hit PowerShell "irm('https://api.example.com')"
t hit PowerShell "& 'irm' https://api.example.com"
t hit PowerShell 'powershell -c "irm https://api.example.com"'
t hit PowerShell $'Get-Location\nirm https://api.example.com/v1/users' 'PowerShell: Get-Location<改行>irm https://...（複数行）'
t hit PowerShell 'Start-BitsTransfer -Source https://example.com/a.zip'
t hit PowerShell "(New-Object Net.WebClient).DownloadString('https://example.com')"
t hit PowerShell '[System.Net.Http.HttpClient]::new()'
t hit PowerShell "[System.Net.WebRequest]::Create('https://example.com')"
t hit PowerShell 'gh api user'
t hit PowerShell 'GH api user'
t hit PowerShell 'curl.exe https://api.example.com/v1/users'
t hit PowerShell 'CURL.EXE https://api.example.com/v1/users'
t hit PowerShell 'AZ.CMD account show'
t hit PowerShell 'az.cmd account show'
t hit PowerShell "& 'C:\Program Files\GitHub CLI\gh.exe' api user"
t hit PowerShell 'C:/Tools/gh.exe api user'
t hit PowerShell '.\gh.exe api user'
t hit PowerShell '& "gh" api user'
t hit PowerShell "& 'gh' api user"
t hit PowerShell '$r=curl.exe https://api.example.com/v1/users'
t hit PowerShell '$u=gh api user'
t hit PowerShell '1..3 | ForEach-Object {gh api user}'
t hit PowerShell "Start-Process -FilePath \"curl.exe\" -ArgumentList 'https://api.example.com'"

echo "=== 4. PowerShell: 認証情報らしい環境変数の設定（case-35） ==="
want='環境変数'
t hit PowerShell '$env:GITHUB_TOKEN = "<dummy>"'
t hit PowerShell '$env:github_token="<dummy>"'
t hit PowerShell '$env:GITHUB_TOKEN += "<dummy>"'
t hit PowerShell "\${env:API_KEY} = '<dummy>'"
t hit PowerShell "[Environment]::SetEnvironmentVariable('OPENAI_API_KEY', '<dummy>', 'User')"
t hit PowerShell '[System.Environment]::SetEnvironmentVariable("DB_PASSWORD", "<dummy>")'
t hit PowerShell "Set-Item -Path Env:DB_PASSWORD -Value '<dummy>'"
t hit PowerShell "Set-Item -Path Env:\\AWS_SECRET_ACCESS_KEY -Value '<dummy>'"
t hit PowerShell "Set-Item Env:/DB_PASSWORD '<dummy>'"
t hit PowerShell "Set-Item -Value '<dummy>' -Path \"Env:MY_TOKEN\""
t hit PowerShell "Set-Content Env:SERVICE_TOKEN '<dummy>'"
t hit PowerShell "New-Item -Path Env: -Name API_KEY -Value '<dummy>'"
t hit PowerShell "si Env:API_KEY '<dummy>'"
t hit PowerShell "ni Env:API_KEY -Value '<dummy>'"
t hit PowerShell 'setx GITHUB_TOKEN "<dummy>"'
t hit PowerShell 'setx /M GITHUB_TOKEN "<dummy>"'
for kw in "${CRED_KW[@]}"; do
  t hit PowerShell "\$env:SAMPLE_${kw} = 1"
done

echo "=== 5. PowerShell: コマンド中の秘密情報パターン（case-36） ==="
want='認証情報パターン'
t hit PowerShell "Write-Output \"$fake_sk\"" 'PowerShell: Write-Output "sk-…"（24 文字のダミー）'
want='Bearer'
t hit PowerShell "\$h = @{ Authorization = \"$fake_bearer\" }" 'PowerShell: $h = @{ Authorization = "Bearer …" }（ダミー）'

echo "=== 6. PowerShell: 通知しないもの（case-37・38・40・41） ==="
want=''
t miss PowerShell '& chcp.com 65001 | Out-Null; [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8; Get-ChildItem -Recurse -Filter *.md' 'PowerShell: （必須プリフィクス）; Get-ChildItem -Recurse -Filter *.md'
t miss PowerShell 'Get-ChildItem -Recurse -Filter *.md'
t miss PowerShell 'Get-Process claude | Select-Object Id, StartTime'
t miss PowerShell 'Get-Command bash -All'
t miss PowerShell 'Write-Output $env:PATH'
t miss PowerShell 'Write-Output $env:GITHUB_TOKEN.Length'
t miss PowerShell 'Get-ChildItem Env:'
t miss PowerShell '$env:MSYS_NO_PATHCONV = 1; Get-Location'
t miss PowerShell '$env:PATH += ";C:\tools"'
t miss PowerShell 'setx JAVA_HOME "C:\jdk"'
t miss PowerShell "[Environment]::SetEnvironmentVariable('PATH', \$p, 'User')"
t miss PowerShell 'Set-Item -Path Env:FOO -Value 1'
t miss PowerShell 'New-Item -Path Env: -Name FOO -Value 1'
t miss PowerShell $'Set-Content a.txt \'x\'\nGet-Item Env:GITHUB_TOKEN' "PowerShell: Set-Content a.txt 'x'<改行>Get-Item Env:GITHUB_TOKEN（2 行目は参照のみ）"
t miss PowerShell 'Set-Location C:\repos\gh-pages; git status'
t miss PowerShell 'Copy-Item .\docs\op\readme.md .\out\'
t miss PowerShell 'Test-Path "$HOME\.ssh"'

echo "=== 7. Bash: 既存の判定（case-19・20・29・30） ==="
want='外部通信'
t hit Bash 'curl -H "Authorization: Bearer X" https://api.example.com/data'
t hit Bash 'echo hi|curl -s https://api.example.com'
t hit Bash 'Invoke-RestMethod https://api.example.com/v1/users'
t hit Bash $'cd /tmp\ncurl https://api.example.com/v1/users' 'Bash: cd /tmp<改行>curl https://...（複数行）'
for name in "${CLI_NAMES[@]}"; do
  t hit Bash "$name --help"
done
want='環境変数'
t hit Bash 'export GITHUB_TOKEN=<dummy>'
t hit Bash 'export TOKEN=<dummy>'
t hit Bash 'export OPENAI_API_KEY=<dummy>'
t hit Bash 'export MY_SESSION_ID=<dummy>'
t hit Bash 'set DB_PASSWORD=<dummy>'
t hit Bash $'echo ok\nexport GITHUB_TOKEN=<dummy>' 'Bash: echo ok<改行>export GITHUB_TOKEN=...（複数行）'
want='認証情報パターン'
t hit Bash "echo \"$fake_sk\"" 'Bash: echo "sk-…"（24 文字のダミー）'
want=''
t miss Bash 'ls -la /tmp && git status'
t miss Bash 'export MSYS_NO_PATHCONV=1; ls'
t miss Bash 'set -euo pipefail; echo ok'
t miss Bash 'GH api user' 'Bash: GH api user（CLI 名は大文字小文字を区別する）'
t miss Bash 'export github_token=<dummy>' 'Bash: export github_token=...（export は大文字小文字を区別する。nocasematch が漏れていないことの確認を兼ねる）'
t miss Bash $'set\nFOO_TOKEN=abc' 'Bash: set<改行>FOO_TOKEN=abc（設定の照合は改行をまたがない）'

echo "=== 8. Bash: Windows / PowerShell の書き方（case-39） ==="
want='外部通信'
t hit Bash 'curl.exe https://api.example.com/v1/users'
t hit Bash 'invoke-restmethod https://api.example.com/v1/users'
t hit Bash 'powershell -c "irm https://api.example.com"'
want='環境変数'
t hit Bash "pwsh -c \"\$env:GITHUB_TOKEN = '<dummy>'\""

echo "=== 9. シェル以外のツール（case-18・21〜23・31） ==="
want='外部 URL'
run hit WebFetch '{"tool_name":"WebFetch","tool_input":{"url":"https://api.openai.com/v1/models","prompt":"get models"}}' 'WebFetch: https://api.openai.com/v1/models'
run hit WebSearch '{"tool_name":"WebSearch","tool_input":{"query":"example"}}' 'WebSearch: example'
want='MCP'
run hit mcp__github__get_me '{"tool_name":"mcp__github__get_me","tool_input":{}}' 'mcp__github__get_me'
run hit mcp__plugin_slack_slack__post '{"tool_name":"mcp__plugin_slack_slack__post","tool_input":{"text":"hi"}}' 'mcp__plugin_slack_slack__post'
want='環境変数定義ファイル'
run hit Read '{"tool_name":"Read","tool_input":{"file_path":"/repo/.env"}}' 'Read: /repo/.env'
run hit Read '{"tool_name":"Read","tool_input":{"file_path":"C:\\repo\\.env"}}' 'Read: C:\repo\.env（Windows のパス）'
run hit Edit '{"tool_name":"Edit","tool_input":{"file_path":"/repo/.env","old_string":"A=1","new_string":"A=2"}}' 'Edit: /repo/.env'
run hit MultiEdit '{"tool_name":"MultiEdit","tool_input":{"file_path":"/repo/.env.local","edits":[{"old_string":"A=1","new_string":"A=2"}]}}' 'MultiEdit: /repo/.env.local'
want='認証情報パターン'
run hit Write "$(jq -cn --arg c "github_token=$fake_ghp" '{tool_name: "Write", tool_input: {file_path: "/tmp/notes.txt", content: $c}}' | tr -d '\r')" 'Write: コンテンツに ghp_…（ダミー）'
run hit Edit "$(jq -cn --arg c "token=$fake_sk" '{tool_name: "Edit", tool_input: {file_path: "/repo/a.txt", old_string: "token=", new_string: $c}}' | tr -d '\r')" 'Edit: コンテンツに sk-…（ダミー）'
run hit NotebookEdit "$(jq -cn --arg c "token = \"$fake_sk\"" '{tool_name: "NotebookEdit", tool_input: {notebook_path: "/repo/a.ipynb", new_source: $c}}' | tr -d '\r')" 'NotebookEdit: コンテンツに sk-…（ダミー）'
want=''
run miss Read '{"tool_name":"Read","tool_input":{"file_path":"/repo/.env.example"}}' 'Read: /repo/.env.example'
run miss Read '{"tool_name":"Read","tool_input":{"file_path":"C:/repo/README.md"}}' 'Read: C:/repo/README.md'
run miss Write '{"tool_name":"Write","tool_input":{"file_path":"/repo/README.md","content":"# title"}}' 'Write: /repo/README.md（通常の内容）'

echo "=== 10. 異常入力（フェイルオープン: 何も出力せず終了コード 0。case-42） ==="
want=''
run miss - '' '空の標準入力'
run miss - $' \n\t ' '空白だけの標準入力'
run miss - '{not json' '不正な JSON'
run miss PowerShell '{"tool_name":"PowerShell","tool_input":{}}' 'PowerShell: command が無い'
out="$(shell_json Bash 'curl https://api.example.com' | PATH=/nonexistent "$SHELL_BIN" "$TARGET" 2>/dev/null)"
rc=$?
if [[ $rc -eq 0 && -z $out ]]; then
  record PASS 'jq が無い環境（PATH に jq が無い）'
else
  record FAIL "jq が無い環境で終了コード $rc・出力あり"
fi

echo "=== 11. 大きな入力（hooks.json の timeout の 8 割以内で判定する） ==="
limit_ms=$(( ${timeout_sec:-60} * 800 ))
printf -v blank '%*s' 300000 ''
for kind in Write PowerShell; do
  if [[ $kind == Write ]]; then
    json="$({ printf '%s' "$blank"; printf 'github_token=%s' "$fake_ghp"; } | jq -Rsc '{tool_name: "Write", tool_input: {file_path: "/repo/big.txt", content: .}}' | tr -d '\r')"
    label='Write: 空白の多い 300 KB のコンテンツ（末尾に ghp_… のダミー）'
  else
    json="$(printf "Write-Output '%s'; irm https://api.example.com" "$blank" | jq -Rsc '{tool_name: "PowerShell", tool_input: {command: .}}' | tr -d '\r')"
    label='PowerShell: 空白の多い 300 KB のコマンド（末尾に irm）'
  fi
  start=$(now_ms)
  ctx="$(judge "$json")"
  elapsed=$(( $(now_ms) - start ))
  if [[ -n $ctx && $ctx != EXIT=* && $ctx != INVALID_OUTPUT && $elapsed -lt $limit_ms ]]; then
    record PASS "$label → ${elapsed} ms"
  else
    record FAIL "$label （${elapsed} ms / 上限 ${limit_ms} ms / 結果: ${ctx:-通知なし}）"
  fi
done

echo "=== 12. 既知の制約（合否に含めない。README の「既知の制約」と対応） ==="
tk hit PowerShell "\$env:GIT_AUTHOR_NAME = 'example'" 'PowerShell: $env:GIT_AUTHOR_NAME = ...（AUTH への部分一致で通知される）'
tk hit PowerShell "\$env:API_BASE_URL = 'https://api.example.com'" 'PowerShell: $env:API_BASE_URL = ...（API への部分一致で通知される）'
tk hit PowerShell 'Set-Location .\terraform' 'PowerShell: Set-Location .\terraform（パスの末尾の要素が CLI 名と一致すると通知される）'
tk hit PowerShell 'Write-Output "HTTP status: 200"' 'PowerShell: Write-Output "HTTP status: 200"（引用符の中の語が CLI 名と一致すると通知される）'
tk hit Bash 'echo "IRM results"' 'Bash: echo "IRM results"（引用符の中の irm / iwr は大文字小文字を問わず通知される）'
tk miss Bash '/usr/bin/curl https://api.example.com/v1/users' 'Bash: /usr/bin/curl https://...（Bash ではパス付きの起動を検出しない）'
tk miss PowerShell "New-Item -Name API_KEY -Path Env: -Value '<dummy>'" 'PowerShell: New-Item -Name ... -Path Env:（-Name を先に書くと検出しない）'
tk miss PowerShell "Set-ItemProperty -Path 'HKCU:\\Environment' -Name GITHUB_TOKEN -Value '<dummy>'" 'PowerShell: HKCU:\Environment への設定（レジストリ経由は検出しない）'
tk miss Bash 'git push origin main' 'Bash: git push（git 経由の通信は検出しない）'
tk miss PowerShell 'Write-Output $env:GITHUB_TOKEN' 'PowerShell: Write-Output $env:GITHUB_TOKEN（値の表示は検出しない）'

echo
printf '結果: PASS=%s FAIL=%s（既知の制約 %s 件のうち挙動が変わったもの %s 件）\n' "$pass" "$fail" "$known" "$changed"
[[ "$fail" -eq 0 ]]
