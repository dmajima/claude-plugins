#!/usr/bin/env bash
# test_hooks.sh
#
# credentials-manager の同梱フック（PreToolUse の preempt_credentials_check.sh・
# UserPromptSubmit の detect_credentials_in_prompt.sh・SessionStart の install_rule_template.sh）と、
# hooks.json の登録の回帰テスト。実際のフック入力 JSON を流し、通知の有無・理由文・出力の形式・所要時間を検証する。
# 後半の群（単体）は lib/ の関数を直接呼び、パターン・ファイル判定・トークン分割を表駆動で検証する。
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
PROMPT_HOOK="$HOOKS/detect_credentials_in_prompt.sh"
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
SHELL_BIN="${BASH:-bash}"   # フックはテストと同じ bash で起動する
JUDGE_SCRIPT=""             # 検証するフック（空なら $TARGET）。UserPromptSubmit の群で切り替える
JUDGE_EVENT=""              # 出力の hookEventName（空なら PreToolUse）

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "ERROR: bash 4 以上で実行してください（フックとこのテストは bash 4 の機能を使う。現在: ${BASH_VERSION:-?}）"
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq が見つかりません（フックは jq が無いと何も出力しないため検証できません）"
  exit 2
fi
if [[ ! -f "$TARGET" || ! -f "$HOOKS_JSON" ]]; then
  echo "ERROR: 検証対象が見つかりません: $TARGET / $HOOKS_JSON"
  exit 2
fi
# SessionStart の配置先や前提を欠く環境の再現に使う一時ディレクトリ（終了時に削除する）
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# 各群で共有する値（群を入れ替えたり一部だけを動かしたりしても未定義にならないよう、ここでまとめて定義する）
rep() { local s="" i; for ((i = 0; i < $2; i++)); do s+=$1; done; printf '%s' "$s"; }  # $1 を $2 回繰り返す
pad24="$(printf '%24s' '')"
fake_sk="sk-${pad24// /x}"
fake_ghp="ghp_${pad24// /z}"
fake_bearer="Bearer ${pad24// /y}"
fake_basic="Basic $(printf '%s' 'demo-user:not-a-real-password' | base64 | tr -d '\r\n')"
printf -v fake_pem '%sBEGIN RSA PRIVATE %s' '-----' 'KEY-----'
printf -v blank '%*s' 300000 ''
big_lines="$(yes x 2>/dev/null | head -n 500000)"                                        # 改行の多い約 1 MB（x と改行の繰り返し）
big_words="$(yes 'lorem ipsum dolor sit amet,' 2>/dev/null | head -n 40000 | tr '\n' ' ')"  # 通常の文の約 1 MB
matcher=""
timeout_sec=""
prompt_timeout_sec=""
prompt_json() { jq -cn --arg p "$1" '{prompt: $p}' | tr -d '\r'; }
TEMPLATE="$PLUGIN_ROOT/references/templates/rules/security/credentials-management.md"
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
  local out rc ctx script=${JUDGE_SCRIPT:-$TARGET} event=${JUDGE_EVENT:-PreToolUse}
  out="$(printf '%s' "$1" | "$SHELL_BIN" "$script" 2>/dev/null)"
  rc=$?
  if [[ $rc -ne 0 ]]; then printf 'EXIT=%s' "$rc"; return; fi
  [[ $out =~ [^[:space:]] ]] || return
  # continue は必ず true（false だとツール呼び出しが止まる）。通知文は該当イベントの additionalContext に入れる
  if ! ctx="$(printf '%s' "$out" | jq -er --arg e "$event" 'select(.continue == true and .hookSpecificOutput.hookEventName == $e) | .hookSpecificOutput.additionalContext' 2>/dev/null)"; then
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

# 大きなフック入力を組み立てる。値はヒアストリングで渡す（printf でパイプに書くと、改行の多い値では 1 行ずつ書き込まれて遅い）
big_json() {  # $1=種別(Bash|PowerShell|Write|prompt) $2=値（Bash / PowerShell はコマンド、Write はコンテンツ）
  case $1 in
    Bash|PowerShell) jq -Rsc --arg t "$1" '{tool_name: $t, tool_input: {command: .}}' <<< "$2" ;;
    Write) jq -Rsc '{tool_name: "Write", tool_input: {file_path: "/repo/big.txt", content: .}}' <<< "$2" ;;
    prompt) jq -Rsc '{prompt: .}' <<< "$2" ;;
  esac | tr -d '\r'
}

# 大きな入力の判定と所要時間を検証する。期待どおりの判定を limit_ms（timeout の 8 割）以内に返せば PASS。
# 理由文は want（空なら照合しない）で確かめる。timeout を超えると通知が無言で欠落するため、時間も合否に含める
perf() {  # $1=期待(hit|miss) $2=フック入力 JSON $3=表示名
  local start ctx elapsed reason
  start=$(now_ms)
  ctx="$(judge "$2")"
  elapsed=$(( $(now_ms) - start ))
  reason="${ctx#\[credentials-manager\] }"
  reason="${reason%%。*}"
  if [[ $ctx == EXIT=* || $ctx == INVALID_OUTPUT ]]; then
    record FAIL "$3 （フックの出力が異常: $ctx）"
  elif [[ ($1 == hit && -z $ctx) || ($1 == miss && -n $ctx) ]]; then
    record FAIL "$3 （期待: $1 / 実際: ${reason:-通知なし}）"
  elif [[ $1 == hit && -n $want && $reason != *"$want"* ]]; then
    record FAIL "$3 （理由文に「$want」が無い: $reason）"
  elif (( elapsed >= limit_ms )); then
    record FAIL "$3 （${elapsed} ms / 上限 ${limit_ms} ms）"
  else
    record PASS "$3 → ${elapsed} ms${reason:+ / $reason}"
  fi
}

echo "=== 1. hooks.json の PreToolUse 登録 ==="
entry="$(jq -c '[.hooks.PreToolUse[]? | select(any(.hooks[]?; (.command // "") | test("preempt_credentials_check\\.sh")))][0] // empty' < "$HOOKS_JSON" | tr -d '\r')"
if [[ -z $entry ]]; then
  record FAIL "PreToolUse に preempt_credentials_check.sh の登録が無い"
else
  matcher="$(printf '%s' "$entry" | jq -r '.matcher // empty' | tr -d '\r')"
  for tool in WebFetch WebSearch Bash PowerShell Read Write Edit MultiEdit NotebookEdit Grep Glob mcp__github__get_me; do
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
# SessionStart / UserPromptSubmit の登録（matcher は持たない）
for pair in SessionStart:install_rule_template.sh UserPromptSubmit:detect_credentials_in_prompt.sh; do
  ev=${pair%%:*}
  sc=${pair#*:}
  def="$(jq -c --arg ev "$ev" --arg sc "$sc" '[.hooks[$ev][]?.hooks[]? | select((.command // "") | contains($sc))][0] // empty' < "$HOOKS_JSON" | tr -d '\r')"
  if [[ -z $def ]]; then
    record FAIL "$ev に $sc の登録が無い"
    continue
  fi
  c="$(printf '%s' "$def" | jq -r '.command' | tr -d '\r')"
  if [[ $c =~ \$\{CLAUDE_PLUGIN_ROOT\}/([^\"]+) && -f "$PLUGIN_ROOT/${BASH_REMATCH[1]}" ]]; then
    record PASS "$ev: command が同梱のスクリプトを指す（${BASH_REMATCH[1]}）"
  else
    record FAIL "$ev: command が同梱のスクリプトを指していない: $c"
  fi
  if [[ "$(printf '%s' "$def" | jq -r '.shell // empty' | tr -d '\r')" == bash ]]; then
    record PASS "$ev: shell が \"bash\""
  else
    record FAIL "$ev: shell が \"bash\" でない"
  fi
  t_sec="$(printf '%s' "$def" | jq -r '.timeout // empty' | tr -d '\r')"
  if [[ $t_sec =~ ^[0-9]+$ ]]; then
    record PASS "$ev: timeout が指定されている（${t_sec} 秒）"
    [[ $ev == UserPromptSubmit ]] && prompt_timeout_sec=$t_sec
  else
    record FAIL "$ev: timeout が未指定（既定の 60 秒になる）"
  fi
done

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
want='に Bearer'
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
t miss PowerShell 'Copy-Item .\docs\ssh-notes.md .\out\' 'PowerShell: Copy-Item .\docs\ssh-notes.md .\out\（パス中の ssh は CLI の ssh ではない）'

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
# jq が無い環境: 標準出力には何も出さず終了コード 0。保護が外れたことは stderr に 1 行出す
for hook in "$TARGET" "$PROMPT_HOOK"; do
  input="$(shell_json Bash 'curl https://api.example.com')"
  [[ $hook == "$PROMPT_HOOK" ]] && input="$(jq -cn --arg p "key=$fake_sk" '{prompt: $p}' | tr -d '\r')"
  printf '%s' "$input" | PATH=/nonexistent "$SHELL_BIN" "$hook" > "$TMP_ROOT/nojq.out" 2> "$TMP_ROOT/nojq.err"
  rc=$?
  name=${hook##*/}
  if [[ $rc -eq 0 && ! -s "$TMP_ROOT/nojq.out" ]] && grep -q 'jq が無い' "$TMP_ROOT/nojq.err"; then
    record PASS "jq が無い環境（$name）: 出力なし・終了コード 0・stderr に 1 行"
  else
    record FAIL "jq が無い環境（$name）: 終了コード $rc / 標準出力 $(wc -c < "$TMP_ROOT/nojq.out") バイト / stderr: $(head -c 100 "$TMP_ROOT/nojq.err")"
  fi
done
# 共通の lib が無い環境（プラグインのファイルの欠け）: 同じく出力なし・終了コード 0・stderr に 1 行
cp -r "$HOOKS" "$TMP_ROOT/hooks-nolib"
rm -rf "$TMP_ROOT/hooks-nolib/lib"
for name in preempt_credentials_check.sh detect_credentials_in_prompt.sh; do
  input="$(shell_json Bash 'curl https://api.example.com')"
  [[ $name == detect_credentials_in_prompt.sh ]] && input="$(prompt_json "key=$fake_sk")"
  printf '%s' "$input" | "$SHELL_BIN" "$TMP_ROOT/hooks-nolib/$name" > "$TMP_ROOT/nolib.out" 2> "$TMP_ROOT/nolib.err"
  rc=$?
  if [[ $rc -eq 0 && ! -s "$TMP_ROOT/nolib.out" ]] && grep -q 'lib/credential_patterns.sh を読み込めない' "$TMP_ROOT/nolib.err"; then
    record PASS "lib が無い環境（$name）: 出力なし・終了コード 0・stderr に 1 行"
  else
    record FAIL "lib が無い環境（$name）: 終了コード $rc / 標準出力 $(wc -c < "$TMP_ROOT/nolib.out") バイト / stderr: $(head -c 100 "$TMP_ROOT/nolib.err")"
  fi
done
# bash が 4 未満の環境（判定の閾値を書き換えた複製で再現）: 同じく出力なし・終了コード 0・stderr に 1 行
cp -r "$HOOKS" "$TMP_ROOT/hooks-oldbash"
for name in preempt_credentials_check.sh detect_credentials_in_prompt.sh; do
  f="$TMP_ROOT/hooks-oldbash/$name"
  s="$(cat "$f"; printf x)"
  s=${s%x}
  if [[ $s != *'-lt 4 ]]'* ]]; then
    record FAIL "bash 4 未満の環境（$name）: 判定の閾値（-lt 4）が見つからず、再現できない"
    continue
  fi
  printf '%s' "${s/-lt 4 ]]/-lt 99 ]]}" > "$f"
  input="$(shell_json Bash 'curl https://api.example.com')"
  [[ $name == detect_credentials_in_prompt.sh ]] && input="$(prompt_json "key=$fake_sk")"
  printf '%s' "$input" | "$SHELL_BIN" "$f" > "$TMP_ROOT/oldbash.out" 2> "$TMP_ROOT/oldbash.err"
  rc=$?
  if [[ $rc -eq 0 && ! -s "$TMP_ROOT/oldbash.out" ]] && grep -q 'bash 4 以上が必要' "$TMP_ROOT/oldbash.err"; then
    record PASS "bash 4 未満の環境（$name）: 出力なし・終了コード 0・stderr に 1 行"
  else
    record FAIL "bash 4 未満の環境（$name）: 終了コード $rc / 標準出力 $(wc -c < "$TMP_ROOT/oldbash.out") バイト / stderr: $(head -c 100 "$TMP_ROOT/oldbash.err")"
  fi
done

echo "=== 11. 大きな入力（hooks.json の timeout の 8 割以内で判定する。256 KB を超える部分も判定の対象にする） ==="
limit_ms=$(( ${timeout_sec:-60} * 800 ))
# コンテンツは 256 KB を超えると grep でまとめて照合する（末尾の秘密情報も検出し、種類も判定する）
want='認証情報パターン'
perf hit "$(big_json Write "${blank}github_token=$fake_ghp")" 'Write: 空白の多い 300 KB のコンテンツ（末尾に ghp_… のダミー）'
perf hit "$(big_json Write "$big_lines"$'\n'"$fake_sk")" 'Write: 改行の多い 1 MB のコンテンツ（末尾に sk-… のダミー）'
want='Bearer'
perf hit "$(big_json Write "$big_words Authorization: $fake_bearer")" 'Write: 1 MB の文（末尾に Bearer … のダミー）'
want=''
perf miss "$(big_json Write "$big_lines")" 'Write: 改行の多い 1 MB のコンテンツ（秘密情報なし）'
# コマンドは先頭 256 KB を照合する。それより長いコマンドは、残りを判定できないものとして控えめに通知する
want='外部通信コマンド'
perf hit "$(big_json PowerShell "Write-Output '${blank:0:200000}'; irm https://api.example.com")" 'PowerShell: 空白の多い 200 KB のコマンド（末尾に irm）'
want='長さが 256 KB を超え'
perf hit "$(big_json PowerShell "Write-Output '$blank'; irm https://api.example.com")" 'PowerShell: 空白の多い 300 KB のコマンド（末尾に irm。256 KB を超える）'
perf hit "$(big_json Bash "echo '$big_words'; curl https://api.example.com")" 'Bash: 1 MB のコマンド（末尾に curl。256 KB を超える）'
want='4 KB を超え'
perf hit "$(big_json Bash "cat $(rep "$(rep a.env1 700) " 256)")" 'Bash: 手掛かりの語を含む 4 KB のトークン 256 個'
want='環境変数定義ファイル'
perf hit "$(big_json Bash "cat $(rep "$(rep '\' 4000).env " 50)")" 'Bash: \ が 4000 個続く .env のトークン 50 個（200 KB）'
want=''

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
tk hit Bash 'echo ".env" >> .gitignore' 'Bash: echo ".env" >> .gitignore（.env を無視する設定の追加も、.env を指すトークンとして通知される）'
tk hit Bash "echo \"Basic $(printf '%s%s' Authentication SchemeHandler)\"" 'Bash: echo "Basic <英字だけの 27 文字の識別子>"（Basic の後に 16 文字以上の英数字が続く語は通知される）'
tk hit Bash 'node -e "console.log(c.key)"' 'Bash: console.log(c.key)（語幹のあるプロパティ c.key は拡張子で通知される）'
tk hit Bash 'sort --order=name.asc' 'Bash: --order=name.asc（語幹のある .asc は拡張子で通知される）'
tk miss Bash 'cat .server.key' 'Bash: cat .server.key（. で始まりパスの区切りを含まない語は、jq のパスと区別できないため拡張子で判定しない）'
tk miss Bash 'cat {config,secrets}.json' 'Bash: cat {config,secrets}.json（シェルの波括弧は展開せずに区切りとして扱う）'
tk miss Bash 'cat ~/.aws/sso/cache/token.json' 'Bash: ~/.aws/sso/cache の JSON（~/.aws は credentials / config とディレクトリそのものだけを対象にする）'

echo "=== 13. UserPromptSubmit: ユーザ入力の秘密情報（case-17・24） ==="
JUDGE_SCRIPT=$PROMPT_HOOK
JUDGE_EVENT=UserPromptSubmit
want='認証情報パターン'
run hit - "$(prompt_json "OpenAI のキーは $fake_sk を使ってください")" 'プロンプト: OpenAI のキーは sk-…（ダミー）を使って'
want='に Bearer'
run hit - "$(prompt_json "Authorization: $fake_bearer で API を呼んで")" 'プロンプト: Authorization: Bearer …（ダミー）'
want='に Basic'
run hit - "$(prompt_json "Authorization: $fake_basic を付けて")" 'プロンプト: Authorization: Basic …（ダミー）'
want='に PEM'
run hit - "$(prompt_json "$fake_pem"$'\nMIIE...\n')" 'プロンプト: PEM 形式の秘密鍵の先頭行（ダミー）'
want=''
run miss - "$(prompt_json 'README の誤字を直して')" 'プロンプト: README の誤字を直して'
run miss - "$(prompt_json 'Basic 認証の設定方法を教えて')" 'プロンプト: Basic 認証の設定方法を教えて'
run miss - '' '空の標準入力'
run miss - '{not json' '不正な JSON'
run miss - '{"prompt":""}' 'prompt が空'
limit_ms=$(( ${prompt_timeout_sec:-60} * 800 ))
want='認証情報パターン'
perf hit "$(big_json prompt "${blank}key=$fake_sk")" 'プロンプト: 空白の多い 300 KB の入力（末尾に sk-… のダミー）'
perf hit "$(big_json prompt "$big_lines"$'\n'"key=$fake_sk")" 'プロンプト: 改行の多い 1 MB の入力（末尾に sk-… のダミー）'
want=''
perf miss "$(big_json prompt "${blank}x")" 'プロンプト: 空白の多い 300 KB の入力（秘密情報なし）'
perf miss "$(big_json prompt "$big_lines")" 'プロンプト: 改行の多い 1 MB の入力（秘密情報なし）'
JUDGE_SCRIPT=""
JUDGE_EVENT=""

echo "=== 14. 秘密情報のパターン（lib/credential_patterns.sh。PreToolUse と UserPromptSubmit で共通。case-44・45・53） ==="
want='に Basic'
t hit Bash "echo \"Authorization: $fake_basic\"" 'Bash: echo "Authorization: Basic …"（ダミー）'
want='に PEM'
t hit PowerShell "Set-Content key.txt '$fake_pem'" "PowerShell: Set-Content key.txt '<PEM の先頭行>'（ダミー）"
run hit Write "$(jq -cn --arg c "$fake_pem"$'\nMIIE\n' '{tool_name: "Write", tool_input: {file_path: "/repo/id.txt", content: $c}}' | tr -d '\r')" 'Write: コンテンツに PEM の先頭行（ダミー）'
want='認証情報パターン'
run hit Write "$(jq -cn --arg c "line1"$'\n'"$fake_sk" '{tool_name: "Write", tool_input: {file_path: "/repo/a.txt", content: $c}}' | tr -d '\r')" 'Write: 2 行目の行頭に sk-…（JSON のエスケープ \n の直後でも一致する）'
t hit Bash "printf 'a\\n${fake_sk}'" "Bash: printf 'a\\n<sk-…>'（エスケープした改行の直後）"
t hit PowerShell "Write-Output \"a\`n${fake_sk}\"" 'PowerShell: Write-Output "a`n<sk-…>"（PowerShell のエスケープの直後）'
t hit Bash "echo 'token%3D${fake_sk}'" "Bash: echo 'token%3D<sk-…>'（URL エンコードの直後）"
run hit MultiEdit "$(jq -cn --arg s "token=$fake_sk" '{tool_name: "MultiEdit", tool_input: {file_path: "/repo/a.txt", edits: [{old_string: "a", new_string: "b"}, {old_string: "x", new_string: $s}]}}' | tr -d '\r')" 'MultiEdit: 2 つ目の edits の new_string に sk-…（入れ子の文字列も照合する）'
run hit Write '{"tool_name":"Write","tool_input":{"file_path":"/repo/a.txt","content":"abc\u0000 '"$fake_sk"'"}}' 'Write: NUL の後ろに sk-…（NUL で照合が途切れない）'
want='SSH'
run hit NotebookEdit '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"/home/u/.ssh/notes.ipynb","new_source":"x = 1"}}' 'NotebookEdit: notebook_path が ~/.ssh/ 配下'
want=''
t miss Bash 'cat docs/task-management-system.md' 'Bash: cat docs/task-management-system.md（語の途中の sk- には一致しない）'
run miss Write '{"tool_name":"Write","cwd":"C:/work/task-management-system-v2","transcript_path":"C:/x/risk-assessment-framework.jsonl","tool_input":{"file_path":"/repo/a.txt","content":"hello"}}' 'Write: cwd / transcript_path にだけ sk- を含む語がある（メタデータは照合しない）'
run miss Edit '{"tool_name":"Edit","tool_input":{"file_path":"/repo/a.md","old_string":"a","new_string":"dev-task-runner-configuration"}}' 'Edit: dev-task-runner-configuration（語の途中の sk- には一致しない）'
JUDGE_SCRIPT=$PROMPT_HOOK
JUDGE_EVENT=UserPromptSubmit
want='認証情報パターン'
run hit - "$(prompt_json "キーは${fake_sk}です")" 'プロンプト: キーはsk-…です（日本語の直後でも一致する）'
want=''
run miss - "$(prompt_json 'task-management-system.md を読んで')" 'プロンプト: task-management-system.md を読んで'
JUDGE_SCRIPT=""
JUDGE_EVENT=""

echo "=== 15. シェルでの認証情報系ファイルの操作（case-46・47・54・55） ==="
want='で環境変数定義ファイル'
t hit Bash 'cat .env'
t hit Bash 'cp .env.example .env.local'
t hit Bash 'git add .env'
t hit PowerShell 'Get-ChildItem -Filter .env*'
t hit Bash $'cd /repo\nsource ./.env' 'Bash: cd /repo<改行>source ./.env（複数行）'
want='で AWS 認証情報ファイル'
t hit PowerShell 'Get-Content $HOME\.aws\credentials'
t hit Bash 'ls ~/.aws'
want='で認証情報を含む可能性が高いファイル'
t hit PowerShell 'type C:\Users\u\.ssh\id_ed25519'
t hit Bash 'chmod 600 ~/.npmrc'
t hit Bash 'jq . config/secrets.json'
want='で SSH 鍵格納ディレクトリ'
t hit Bash 'ls -la ~/.ssh'
t hit PowerShell 'Test-Path "$HOME\.ssh"' 'PowerShell: Test-Path "$HOME\.ssh"（ディレクトリそのものも対象）'
want='で秘密鍵 / 証明書らしい拡張子のファイル'
t hit Bash "find . -name '*.pem'"
t hit PowerShell 'openssl x509 -in server.crt -noout -text'
t hit Bash 'cat ./.server.key' 'Bash: cat ./.server.key（パスの区切りを含む隠しファイル）'
t hit Bash 'openssl x509 -in $HOME/certs/server.pem' 'Bash: $HOME/certs/server.pem（$ で始まってもパスの区切りを含む）'
want='で環境変数定義ファイル'
t hit Bash 'direnv allow && cat .envrc' 'Bash: cat .envrc（direnv）'
want='で GitHub CLI の認証ファイル'
t hit Bash 'cat ~/.config/gh/hosts.yml'
t hit PowerShell 'Get-Content "$env:APPDATA\GitHub CLI\hosts.yml"' 'PowerShell: Get-Content "$env:APPDATA\GitHub CLI\hosts.yml"（空白で分かれたトークン）'
want=''
t miss Bash "jq -r '.key' data.json" "Bash: jq -r '.key' data.json（語幹の無い .key は対象外）"
t miss Bash "jq -r '.data.key' data.json" "Bash: jq -r '.data.key' data.json（jq のパスは拡張子で判定しない）"
t miss PowerShell 'Get-ChildItem Env: | ForEach-Object { $_.Key }' 'PowerShell: $_.Key（変数のプロパティは拡張子で判定しない）'
t miss Bash 'cat config/hosts.yml' 'Bash: cat config/hosts.yml（GitHub CLI の設定ディレクトリではない）'
t miss Bash 'cat .env.example'
t miss Bash 'ls plugins/credentials-manager/skills'
t miss Bash 'grep -rn secret-scan docs/'
t miss PowerShell 'Get-Content README.md'
t miss Bash 'npm run build'
# 手掛かりの語を含むトークンが上限（256 個）を超えたら、判定を打ち切って控えめに通知する（無言で欠落させない）
want='多数含むコマンド'
decoys=""
for ((i = 0; i < 300; i++)); do decoys+='a.env1 '; done
t hit Bash "cat $decoys" 'Bash: cat a.env1 a.env1 …（300 個。判定の上限を超える）'
# 最悪ケースの所要時間（timeout の 8 割以内）
limit_ms=$(( ${timeout_sec:-60} * 800 ))
want='多数含むコマンド'
perf hit "$(big_json Bash "cat $(rep 'a.env1 ' 20000)~/.aws/credentials")" 'Bash: 手掛かりの語を含むトークン 2 万個の後に ~/.aws/credentials'
want='環境変数定義ファイル'
perf hit "$(big_json Bash "echo $(rep ';' 100000) .env")" 'Bash: 区切り文字 10 万個の後に .env'
want=''

echo "=== 16. Grep / Glob の検索対象（case-48・49） ==="
want='Grep で環境変数定義ファイル'
run hit Grep '{"tool_name":"Grep","tool_input":{"pattern":"API_KEY","path":"/repo/.env"}}' 'Grep: path が /repo/.env'
run hit Grep '{"tool_name":"Grep","tool_input":{"pattern":"token","glob":"**/.env*"}}' 'Grep: glob が **/.env*'
want='Grep で SSH 鍵格納ディレクトリ'
run hit Grep '{"tool_name":"Grep","tool_input":{"pattern":"Host","path":"C:\\Users\\u\\.ssh"}}' 'Grep: path が C:\Users\u\.ssh（ディレクトリ）'
want='Glob で秘密鍵 / 証明書らしい拡張子のファイル'
run hit Glob '{"tool_name":"Glob","tool_input":{"pattern":"**/*.pem"}}' 'Glob: pattern が **/*.pem'
want='Glob で認証情報を含む可能性が高いファイル'
run hit Glob '{"tool_name":"Glob","tool_input":{"pattern":"**/credentials*.json","path":"/repo"}}' 'Glob: pattern が **/credentials*.json'
# 波括弧は展開した候補ごとに判定する
want='Glob で環境変数定義ファイル'
run hit Glob '{"tool_name":"Glob","tool_input":{"pattern":"**/{.env,*.pem}"}}' 'Glob: pattern が **/{.env,*.pem}（波括弧）'
want='Grep で秘密鍵 / 証明書らしい拡張子のファイル'
run hit Grep '{"tool_name":"Grep","tool_input":{"pattern":"BEGIN","glob":"*.{pem,key}"}}' 'Grep: glob が *.{pem,key}（波括弧）'
want='Glob で認証情報を含む可能性が高いファイル'
run hit Glob '{"tool_name":"Glob","tool_input":{"pattern":"config/{settings,secrets}.json"}}' 'Glob: pattern が config/{settings,secrets}.json（波括弧の中が名前の一部）'
want='Glob で波括弧の候補が多く'
run hit Glob "$(jq -cn --arg p "{$(rep 'a,' 70)b}.txt" '{tool_name: "Glob", tool_input: {pattern: $p}}' | tr -d '\r')" 'Glob: 波括弧の候補が 71 個（上限を超える。控えめに通知）'
# 特殊ディレクトリは、配下をワイルドカードだけで指すものとディレクトリそのものも対象
want='Glob で AWS 認証情報ファイル'
run hit Glob '{"tool_name":"Glob","tool_input":{"pattern":"~/.aws/*"}}' 'Glob: pattern が ~/.aws/*'
want='Glob で Kubernetes 認証ファイル'
run hit Glob '{"tool_name":"Glob","tool_input":{"pattern":"**/.kube/**"}}' 'Glob: pattern が **/.kube/**'
want='Glob で SSH 鍵格納ディレクトリ'
run hit Glob '{"tool_name":"Glob","tool_input":{"pattern":"*","path":"~/.ssh"}}' 'Glob: path が ~/.ssh'
want=''
run miss Grep '{"tool_name":"Grep","tool_input":{"pattern":"\\.env","path":"/repo/src"}}' 'Grep: pattern（検索する正規表現）が \.env でも判定しない'
run miss Glob '{"tool_name":"Glob","tool_input":{"pattern":"src/**/*.{ts,tsx}"}}' 'Glob: src/**/*.{ts,tsx}（波括弧を展開しても該当しない）'
run miss Grep '{"tool_name":"Grep","tool_input":{"pattern":"TODO","glob":"*.md","path":"/repo"}}' 'Grep: *.md を検索'
run miss Glob '{"tool_name":"Glob","tool_input":{"pattern":"plugins/credentials-manager/**/*.md"}}' 'Glob: plugins/credentials-manager/**/*.md（語の一部の一致では判定しない）'
run miss Glob '{"tool_name":"Glob","tool_input":{"pattern":"**/.env.example"}}' 'Glob: **/.env.example（除外リスト）'
run miss Glob '{"tool_name":"Glob","tool_input":{}}' 'Glob: 入力が空'

echo "=== 17. SessionStart: ルールの配置と自己診断（case-14〜16・25・50〜52） ==="
# $1=ラベル $2=CLAUDE_PLUGIN_ROOT $3=配置先のプロジェクト $4=PATH（空なら現在の PATH）→ SESSION_OUT / SESSION_RC
session_run() {
  local root=$2 project=$3 path_val=${4:-$PATH}
  printf '{}' | env PATH="$path_val" HOME="$TMP_ROOT/home" USERPROFILE="$TMP_ROOT/home" \
    CLAUDE_PLUGIN_ROOT="$root" CLAUDE_PROJECT_DIR="$project" "$SHELL_BIN" "$root/references/scripts/hooks/install_rule_template.sh" \
    > "$TMP_ROOT/session.out" 2>/dev/null
  SESSION_RC=$?
  SESSION_OUT="$(tr -d '\r' < "$TMP_ROOT/session.out")"
}
session_ctx() { printf '%s' "$SESSION_OUT" | jq -er 'select(.continue == true and .hookSpecificOutput.hookEventName == "SessionStart") | .hookSpecificOutput.additionalContext' 2>/dev/null | tr -d '\r'; }
# project スコープ: プラグインが ~/.claude の外にある
session_run "" "$PLUGIN_ROOT" "$TMP_ROOT/project"
placed="$TMP_ROOT/project/.claude/rules/security/credentials-management.md"
if [[ $SESSION_RC -eq 0 && "$(session_ctx)" == *project*配置しました* ]] && cmp -s "$placed" "$TEMPLATE"; then
  record PASS 'project スコープ: テンプレートを配置して通知する'
else
  record FAIL "project スコープ: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:120}"
fi
session_run "" "$PLUGIN_ROOT" "$TMP_ROOT/project"
if [[ $SESSION_RC -eq 0 && -z $SESSION_OUT ]] && cmp -s "$placed" "$TEMPLATE"; then
  record PASS '配置済み: 何も出力せず、既存のファイルを上書きしない'
else
  record FAIL "配置済み: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:120}"
fi
# user スコープ: プラグインが ~/.claude の配下にある
mkdir -p "$TMP_ROOT/home/.claude/plugins"
cp -r "$PLUGIN_ROOT" "$TMP_ROOT/home/.claude/plugins/cm"
session_run "" "$TMP_ROOT/home/.claude/plugins/cm" "$TMP_ROOT/project-u"
if [[ $SESSION_RC -eq 0 && "$(session_ctx)" == *user*配置しました* ]] && cmp -s "$TMP_ROOT/home/.claude/rules/security/credentials-management.md" "$TEMPLATE"; then
  record PASS 'user スコープ: ~/.claude/rules/security に配置する'
else
  record FAIL "user スコープ: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:120}"
fi
# 指定したコマンドだけを使える PATH 用のディレクトリを作る（各コマンドは元の実行ファイルを絶対パスで呼ぶラッパー）。
# jq と mkdir / cp が同じディレクトリにある環境（Linux の /usr/bin 等）でも、jq だけが無い状態を再現するため
make_bin() {  # $1=ディレクトリ $2...=コマンド名
  local dir=$1 c p
  shift
  mkdir -p "$dir"
  for c in "$@"; do
    p="$(command -v "$c")" || continue
    printf '#!%s\nexec "%s" "$@"\n' "$SHELL_BIN" "$p" > "$dir/$c"
    chmod +x "$dir/$c"
  done
}
count_of() { local s=$1 n=0; while [[ $s == *"$2"* ]]; do s=${s#*"$2"}; n=$((n + 1)); done; printf '%s' "$n"; }  # $1 に $2 が現れる回数
placed_ok() { cmp -s "$1/.claude/rules/security/credentials-management.md" "$TEMPLATE"; }  # $1=プロジェクト
make_bin "$TMP_ROOT/bin-nojq" mkdir cp
# 自己診断: jq が無い（mkdir / cp は使える）→ ルールを配置し、検出フックが動作しないことと対処を平文で知らせる
session_run "" "$PLUGIN_ROOT" "$TMP_ROOT/project-nojq" "$TMP_ROOT/bin-nojq"
if [[ $SESSION_RC -eq 0 && $SESSION_OUT != '{'* && $SESSION_OUT == *'jq が見つからない'*'jq をインストールする'*配置しました* ]] && placed_ok "$TMP_ROOT/project-nojq"; then
  record PASS '自己診断: jq が無くてもルールを配置し、検出フックが動作しないことと対処を平文で知らせる'
else
  record FAIL "自己診断（jq なし）: 終了コード $SESSION_RC / 配置 $(placed_ok "$TMP_ROOT/project-nojq" && echo あり || echo なし) / 出力: ${SESSION_OUT:0:160}"
fi
# 自己診断: 共通のパターン定義が無い → 配置の通知に添えて、プラグインの入れ直しを案内する
cp -r "$PLUGIN_ROOT" "$TMP_ROOT/nolib"
rm -rf "$TMP_ROOT/nolib/references/scripts/hooks/lib"
session_run "" "$TMP_ROOT/nolib" "$TMP_ROOT/project-nolib"
ctx="$(session_ctx)"
if [[ $SESSION_RC -eq 0 && $ctx == *'lib/credential_patterns.sh が無い'*'プラグインを更新するか入れ直す'*配置しました* && $ctx != *'jq をインストール'* ]]; then
  record PASS '自己診断: lib が無いと、配置の通知に添えてプラグインの入れ直しを案内する'
else
  record FAIL "自己診断（lib なし）: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:160}"
fi
# 自己診断: 問題が複数（jq なし・lib 2 つなし）→ すべての問題を挙げ、同じ対処は 1 回だけ案内する
session_run "" "$TMP_ROOT/nolib" "$TMP_ROOT/project-multi" "$TMP_ROOT/bin-nojq"
if [[ $SESSION_RC -eq 0 && $SESSION_OUT == *'jq が見つからない'*'lib/credential_patterns.sh が無い'*'lib/credential_files.sh が無い'* \
      && $(count_of "$SESSION_OUT" 'プラグインを更新するか入れ直す') -eq 1 && $SESSION_OUT == *'jq をインストールする'* ]] && placed_ok "$TMP_ROOT/project-multi"; then
  record PASS '自己診断: 問題が複数でも、すべての問題と対処（重複なし）を知らせてルールを配置する'
else
  record FAIL "自己診断（複数）: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:200}"
fi
# 自己診断: bash が 4 未満（判定の閾値を書き換えた複製で再現）→ ルールを配置し、bash の更新を案内する
cp -r "$PLUGIN_ROOT" "$TMP_ROOT/oldbash"
f="$TMP_ROOT/oldbash/references/scripts/hooks/install_rule_template.sh"
s="$(cat "$f"; printf x)"
s=${s%x}
if [[ $s == *'-lt 4 ]]'* ]]; then
  printf '%s' "${s/-lt 4 ]]/-lt 99 ]]}" > "$f"
  session_run "" "$TMP_ROOT/oldbash" "$TMP_ROOT/project-oldbash"
  ctx="$(session_ctx)"
  if [[ $SESSION_RC -eq 0 && $ctx == *'では動かない（4 以上が必要）'*'bash 4 以上を使う'*配置しました* ]] && placed_ok "$TMP_ROOT/project-oldbash"; then
    record PASS '自己診断: bash が 4 未満でもルールを配置し、bash の更新を案内する'
  else
    record FAIL "自己診断（bash 4 未満）: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:160}"
  fi
else
  record FAIL '自己診断（bash 4 未満）: 判定の閾値（-lt 4）が見つからず、再現できない'
fi
# SessionStart のスクリプトは bash 3.2 でも動く書き方に限る（検出フックが動かない環境でもルールを配置するため）。
# bash 4 以降の構文が無いことを確かめる（コメント行は除く）
b4="$(grep -nE ',,\}|\^\^\}|declare -A|local -A|mapfile|readarray|coproc|\|&|&>>|;;&|@Q\}|\[\[ -v ' "$HOOKS/install_rule_template.sh" | grep -vE '^[0-9]+:[[:space:]]*#')"
if [[ -z $b4 ]]; then
  record PASS 'install_rule_template.sh に bash 4 以降の構文が無い'
else
  record FAIL "install_rule_template.sh に bash 4 以降の構文がある: ${b4:0:120}"
fi
# 配置に失敗した（.claude がファイルでディレクトリを作れない / コピーに失敗）→ 終了コード 0 で、配置できなかったことを知らせる
mkdir -p "$TMP_ROOT/project-blocked"
: > "$TMP_ROOT/project-blocked/.claude"
session_run "" "$PLUGIN_ROOT" "$TMP_ROOT/project-blocked"
if [[ $SESSION_RC -eq 0 && "$(session_ctx)" == *配置できませんでした* ]]; then
  record PASS '配置の失敗（ディレクトリを作れない）: 終了コード 0 で、配置できなかったことを知らせる'
else
  record FAIL "配置の失敗（mkdir）: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:160}"
fi
make_bin "$TMP_ROOT/bin-failcp" mkdir jq
printf '#!%s\nexit 1\n' "$SHELL_BIN" > "$TMP_ROOT/bin-failcp/cp"
chmod +x "$TMP_ROOT/bin-failcp/cp"
session_run "" "$PLUGIN_ROOT" "$TMP_ROOT/project-failcp" "$TMP_ROOT/bin-failcp"
if [[ $SESSION_RC -eq 0 && "$(session_ctx)" == *配置できませんでした* ]] && ! placed_ok "$TMP_ROOT/project-failcp"; then
  record PASS '配置の失敗（コピーできない）: 終了コード 0 で、配置できなかったことを知らせる'
else
  record FAIL "配置の失敗（cp）: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:160}"
fi
# CLAUDE_PLUGIN_ROOT が無い（前提は満たす）→ 何も出力しない
printf '{}' | env HOME="$TMP_ROOT/home" USERPROFILE="$TMP_ROOT/home" CLAUDE_PLUGIN_ROOT= CLAUDE_PROJECT_DIR="$TMP_ROOT/project-x" \
  "$SHELL_BIN" "$HOOKS/install_rule_template.sh" > "$TMP_ROOT/session.out" 2>/dev/null
rc=$?
if [[ $rc -eq 0 && ! -s "$TMP_ROOT/session.out" && ! -e "$TMP_ROOT/project-x" ]]; then
  record PASS 'CLAUDE_PLUGIN_ROOT が無い: 何も出力せず終了コード 0'
else
  record FAIL "CLAUDE_PLUGIN_ROOT が無い: 終了コード $rc / 出力 $(wc -c < "$TMP_ROOT/session.out") バイト"
fi

echo "=== 18. ルールテンプレート・README の記載と PreToolUse の matcher の突き合わせ ==="
# 記載と実装の食い違い（記載にあるツールが matcher に無い、またはその逆）を検出する
doc_tools() {  # $1=ファイル $2=表の開始の行（正規表現） $3=表の終了の行（正規表現）→ 1 列目に書かれたツール名
  awk -v s="$2" -v e="$3" '$0 ~ s {f=1; next} f && $0 ~ e {f=0} f && /^\|/ {n=split($0, c, "|"); print c[2]}' "$1" \
    | grep -oE '`(mcp__\*|[A-Z][A-Za-z]+)`' | tr -d '`' | sort -u
}
IFS='|' read -ra matcher_tools <<< "${matcher//mcp__.\*/mcp__*}"
for doc in "ルールテンプレート 1.3|$TEMPLATE|^### 1\\.3|^認証情報系ファイル" "README の「1. ツール種別による検出」|$PLUGIN_ROOT/README.md|^#### 1\\. ツール種別による検出|^#### 2\\."; do
  IFS='|' read -r dname dfile dstart dend <<< "$doc"
  mapfile -t listed < <(doc_tools "$dfile" "$dstart" "$dend")
  if [[ ${#listed[@]} -eq 0 ]]; then
    record FAIL "$dname: ツール名を読み取れない（表の見出しが変わった可能性）"
    continue
  fi
  missing_in_matcher=()
  for tool in "${listed[@]}"; do
    [[ " ${matcher_tools[*]} " == *" $tool "* ]] || missing_in_matcher+=("$tool")
  done
  missing_in_doc=()
  for tool in "${matcher_tools[@]}"; do
    [[ " ${listed[*]} " == *" $tool "* ]] || missing_in_doc+=("$tool")
  done
  if [[ ${#missing_in_matcher[@]} -eq 0 && ${#missing_in_doc[@]} -eq 0 ]]; then
    record PASS "$dname と matcher のツールが一致する（${#listed[@]} 件）"
  else
    record FAIL "$dname と matcher が食い違う（記載のみ: ${missing_in_matcher[*]:-なし} / matcher のみ: ${missing_in_doc[*]:-なし}）"
  fi
done

# ---- 単体テスト（共通の lib を読み込み、関数を直接呼ぶ。フックの起動を伴わないため速い）----
# shellcheck source=/dev/null
source "$HOOKS/lib/credential_patterns.sh"
# shellcheck source=/dev/null
source "$HOOKS/lib/credential_files.sh"
u_check() {  # $1=期待(hit|miss) $2=実際(hit|miss) $3=表示名 [$4=補足]
  if [[ $2 == "$1" ]]; then record PASS "$3 → $2${4:+（$4）}"; else record FAIL "$3 （期待: $1 / 実際: $2${4:+ / $4}）"; fi
}
u_secret() {  # $1=期待 $2=文字列 $3=表示名 [$4=CRED_LABEL に含まれるべき語]
  local got=miss
  cred_find_secret "$2" && got=hit
  if [[ $got == hit && -n ${4:-} && $CRED_LABEL != *"$4"* ]]; then
    record FAIL "$3 （種類の語句に「$4」が無い: $CRED_LABEL）"
    return
  fi
  u_check "$1" "$got" "$3" "$CRED_LABEL"
}
u_file() {  # $1=期待 $2=パス $3=表示名 [$4=CF_REASON に含まれるべき語]
  local got=miss
  credential_file_reason "$2"
  [[ -n $CF_REASON ]] && got=hit
  if [[ $got == hit && -n ${4:-} && $CF_REASON != *"$4"* ]]; then
    record FAIL "$3 （理由文に「$4」が無い: $CF_REASON）"
    return
  fi
  u_check "$1" "$got" "$3"
}
u_scan() {  # $1=期待 $2=コマンド $3=表示名
  local got=miss
  cred_scan_command_files "$2" && got=hit
  u_check "$1" "$got" "$3"
}

echo "=== 19. 単体: 秘密情報のパターン（全形式・最小長・左側の境界） ==="
a15=$(rep a 15); a16=$(rep a 16); b19=$(rep b 19); b20=$(rep b 20)
u_secret hit "sk-$a16" 'sk- + 16 文字'
u_secret miss "sk-$a15" 'sk- + 15 文字'
u_secret hit "sk-proj-$b20" 'sk-proj- 形式'
for p in ghp_ gho_ ghu_ ghs_ ghr_ glpat-; do
  u_secret hit "$p$b20" "$p + 20 文字"
  u_secret miss "$p$b19" "$p + 19 文字"
done
for p in xoxb- xoxp- xoxa- xoxr- xoxs-; do
  u_secret hit "$p$(rep c 10)" "$p + 10 文字"
  u_secret miss "$p$(rep c 9)" "$p + 9 文字"
done
u_secret hit "AKIA$(rep A 16)" 'AKIA + 英大文字・数字 16 文字'
u_secret miss "AKIA$(rep A 15)" 'AKIA + 15 文字'
u_secret hit "AIza$(rep d 35)" 'AIza + 35 文字'
u_secret miss "AIza$(rep d 34)" 'AIza + 34 文字'
u_secret hit "eyJ$(rep e 8).$(rep f 4).$(rep g 4)" 'JWT（eyJ の後に 8 文字）'
u_secret miss "eyJ$(rep e 7).$(rep f 4).$(rep g 4)" 'JWT（eyJ の後に 7 文字）'
u_secret hit "Bearer $a16" 'Bearer + 16 文字'
u_secret hit "bearer $a16" 'bearer（小文字）+ 16 文字'
u_secret miss "Bearer $a15" 'Bearer + 15 文字'
u_secret hit "Basic $a16" 'Basic + 16 文字'
u_secret miss "Basic $a15" 'Basic + 15 文字'
for kind in 'RSA ' 'DSA ' 'EC ' 'OPENSSH ' 'ENCRYPTED ' ''; do
  printf -v pem '%sBEGIN %sPRIVATE %s' '-----' "$kind" 'KEY-----'
  u_secret hit "$pem" "PEM の先頭行（${kind:-種別なし}）"
done
printf -v pem '%sBEGIN PUBLIC %s' '-----' 'KEY-----'
u_secret miss "$pem" 'PEM の公開鍵の先頭行'
printf -v pem '%sBEGIN PGP PRIVATE KEY BLOCK%s' '-----' '-----'
u_secret hit "$pem" 'PEM の先頭行（PGP の秘密鍵。KEY の後に BLOCK）' 'PEM'
printf -v pem '%sBEGIN PGP PUBLIC KEY BLOCK%s' '-----' '-----'
u_secret miss "$pem" 'PGP の公開鍵の先頭行'
# 左側の境界には、エスケープした改行・タブ（\n \r \t / `n `r `t）と URL エンコード（%XX）の直後も含める
for pre in '\n' '\r' '\t' '`n' '`r' '`t' '%3D' '%3d' '%2F'; do
  u_secret hit "x${pre}sk-$a16" "sk- の直前が「$pre」（エスケープ・URL エンコード）"
done
for pre in '\x' '`x' '%3' '%G1'; do
  u_secret miss "x${pre}sk-$a16" "sk- の直前が「$pre」（エスケープ・URL エンコードではない）"
done
for pre in a Z 0 _ -; do
  u_secret miss "x${pre}sk-$a16" "sk- の直前が「$pre」（語の途中）"
done
for pre in ' ' '=' '"' "'" ':' '(' '/' $'\n' $'\t'; do
  u_secret hit "x${pre}sk-$a16" "sk- の直前が「$(printf '%q' "$pre")」"
done
u_secret hit "sk-$a16" 'sk- が文字列の先頭'
# 256 KB（CRED_SCAN_MAX）を超える文字列は grep でまとめて照合する。境界の前後で判定が変わらず、
# 種類・優先順・左側の境界・改行の扱いも bash の照合と同じであること
printf -v sp '%*s' $((CRED_SCAN_MAX - ${#fake_sk})) ''
u_secret hit "$sp$fake_sk" "長さ $CRED_SCAN_MAX 文字（bash で照合）の末尾に sk-" '認証情報パターン'
u_secret hit " $sp$fake_sk" "長さ $((CRED_SCAN_MAX + 1)) 文字（grep で照合）の末尾に sk-" '認証情報パターン'
printf -v sp '%*s' "$CRED_SCAN_MAX" ''
u_secret hit "$sp$fake_bearer" '256 KB 超の末尾に Bearer' 'Bearer'
u_secret hit "${sp}bearer $a16" '256 KB 超の末尾に bearer（小文字）' 'Bearer'
u_secret hit "$sp$fake_basic" '256 KB 超の末尾に Basic' 'Basic'
u_secret hit "$sp$fake_pem" '256 KB 超の末尾に PEM の先頭行' 'PEM'
u_secret hit "$sp$fake_bearer $fake_sk" '256 KB 超に Bearer と sk- の両方（bash と同じく既知のトークン形式を優先）' '認証情報パターン'
u_secret hit "${sp}x"$'\n'"sk-$a16" '256 KB 超・sk- の直前が改行'
u_secret hit "${sp}Bearer"$'\n'"$a16" '256 KB 超・Bearer の後に改行してトークン（grep は行ごとに照合するが、改行をまたいでも一致する）' 'Bearer'
u_secret hit "${sp}Bearer${sp:0:5000}$a16" '256 KB 超・Bearer の後に空白 5000 個（一致した部分が 4 KB で切れても通知する）'
u_secret miss "${sp}xsk-$a16" '256 KB 超・sk- の直前が英字（語の途中）'
u_secret hit "${sp}x\\nsk-$a16" '256 KB 超・sk- の直前がエスケープした改行（\n）'
printf -v pem '%sBEGIN PGP PRIVATE KEY BLOCK%s' '-----' '-----'
u_secret hit "$sp$pem" '256 KB 超の末尾に PGP の秘密鍵の先頭行' 'PEM'
u_secret miss "${sp}sk-$a15" '256 KB 超・sk- + 15 文字'
u_secret miss "$sp" '256 KB 超・空白だけ'
u_secret miss "$big_lines" '改行の多い 1 MB・秘密情報なし'

echo "=== 20. 単体: 認証情報系ファイルの判定（ルールテンプレートの表から生成） ==="
mapfile -t file_rows < <(awk '/^認証情報系ファイル（/{f=1; next} f && /^\|/ {seen=1; print; next} f && seen {exit}' "$TEMPLATE" | tail -n +3)
if [[ ${#file_rows[@]} -lt 5 ]]; then
  record FAIL "ルールテンプレートの認証情報系ファイルの表を読み取れない（${#file_rows[@]} 行）"
fi
for row in "${file_rows[@]}"; do
  IFS='|' read -r _ kind targets _ <<< "$row"
  kind=${kind# }
  kind=${kind% }
  mapfile -t names < <(grep -oE '`[^`]+`' <<< "$targets" | tr -d '`')
  for n in "${names[@]}"; do
    case "$kind" in
      環境変数定義)
        case "$n" in
          .env) u_file hit "/repo/.env" "テンプレート（$kind）: .env" ;;
          .envrc) u_file hit "/repo/.envrc" "テンプレート（$kind）: .envrc" ;;
          '.env.<name>') u_file hit "/repo/.env.local" "テンプレート（$kind）: .env.local" ;;
          .env.*) u_file miss "/repo/$n" "テンプレート（$kind の除外）: $n" ;;
          .*) u_file miss "/repo/.env$n" "テンプレート（$kind の除外）: .env$n" ;;
        esac
        ;;
      拡張子)
        u_file hit "/repo/server${n#\*}" "テンプレート（$kind）: server${n#\*}"
        u_file miss "${n#\*}" "テンプレート（$kind・語幹なし）: ${n#\*}"
        ;;
      ディレクトリ全体)
        u_file hit "$n" "テンプレート（$kind）: $n"
        u_file hit "$n/config" "テンプレート（$kind）: $n/config"
        ;;
      *)
        if [[ $n == '~/'* ]]; then
          u_file hit "$n" "テンプレート（$kind）: $n"
        else
          u_file hit "/repo/$n" "テンプレート（$kind）: $n"
        fi
        ;;
    esac
  done
done
u_file hit '/repo/CREDENTIALS.JSON' '大文字のファイル名'
u_file hit 'C:\Users\U\.SSH\ID_RSA' 'Windows の区切り・大文字'
u_file hit '.env*' 'ワイルドカード: .env*'
u_file hit 'id_rsa*' 'ワイルドカード: id_rsa*'
u_file hit '**/*.pem' 'ワイルドカード: **/*.pem'
u_file miss '*credentials-manager*' 'ワイルドカード: *credentials-manager*（語の一部）'
u_file miss 'plugins/credentials-manager/README.md' '語の一部: plugins/credentials-manager/README.md'
u_file miss '/repo/.env.spec' '除外リスト: .env.spec'
# Windows はファイル名の末尾の空白・ピリオドと ::$DATA を無視するため、同じファイルとして判定する
u_file hit '/repo/.env ' 'Windows: 末尾に空白の付いた .env' '(.env)'
u_file hit '/repo/.env.' 'Windows: 末尾にピリオドの付いた .env' '(.env)'
u_file hit '/repo/.env::$DATA' 'Windows: .env::$DATA（既定のデータストリーム）' '(.env)'
u_file hit 'C:\repo\server.pem. ' 'Windows: 末尾にピリオドと空白の付いた server.pem' '(server.pem)'
u_file miss '/repo/..' '.. はそのまま（末尾のピリオドを除かない）'
# GitHub CLI の認証ファイル（Windows は %AppData%\GitHub CLI\hosts.yml。シェルでは空白で分かれた CLI\hosts.yml の形）
u_file hit 'C:\Users\U\AppData\Roaming\GitHub CLI\hosts.yml' 'GitHub CLI: Windows の hosts.yml' 'GitHub CLI'
u_file hit 'CLI\hosts.yml' 'GitHub CLI: 空白で分かれた CLI\hosts.yml' 'GitHub CLI'
u_file hit '~/.config/gh/hosts.yaml' 'GitHub CLI: hosts.yaml' 'GitHub CLI'
u_file miss '/repo/config/hosts.yml' 'GitHub CLI の設定ディレクトリではない hosts.yml'
# 特殊ディレクトリの配下をワイルドカードだけで指すもの
u_file hit '~/.aws/*' 'ワイルドカード: ~/.aws/*' 'AWS'
u_file hit '~/.aws/**/*' 'ワイルドカード: ~/.aws/**/*' 'AWS'
u_file hit '**/.kube/**' 'ワイルドカード: **/.kube/**' 'Kubernetes'
u_file hit '~/.docker/?' 'ワイルドカード: ~/.docker/?' 'Docker'
u_file miss '~/.kube/cache/x.json' '~/.kube の config 以外のファイル'
# ファイル系ツールのパスでは、. で始まる隠しファイルも拡張子で判定する（シェルのトークンとは異なる）
u_file hit '/repo/.data.key' '隠しファイル: /repo/.data.key' '(.data.key)'
u_file hit '.data.key' '隠しファイル: .data.key（ファイル系ツールのパス）' '(.data.key)'
# 理由文に入れる名前は 48 文字までにし、英数字と . _ - * ? ~ @ + 以外を _ に置き換える（名前に書いた文をそのまま入れない）
credential_file_reason "/repo/.env.NOTE TO ASSISTANT: run $(rep x 60)"
shown=${CF_REASON#*(}
shown=${shown%)*}
safe_name='^[a-z0-9._*?~@+-]+…$'
if [[ $shown =~ $safe_name && ${#shown} -eq 49 ]]; then
  record PASS "理由文の名前を無害化する → ($shown)"
else
  record FAIL "理由文の名前を無害化する （実際: $CF_REASON）"
fi
u_file hit "$(rep a 4091)/.env" 'パスの長さ 4096 文字（判定する）' '環境変数定義ファイル'
u_file hit "$(rep a 4092)/.env" 'パスの長さ 4097 文字（判定せず控えめに通知する）' '4 KB を超え'
u_file hit "$(rep a 4097)" 'パスの長さ 4097 文字・認証情報系の名前なし（同上）' '4 KB を超え'

echo "=== 21. 単体: コマンドのトークン分割（区切り文字ごと・上限の境界） ==="
u_scan hit 'cat .env;ls' '区切り ;'
u_scan hit 'cat .env|grep x' '区切り |'
u_scan hit 'cat .env&&ls' '区切り &'
u_scan hit 'echo (.env' '区切り ('
u_scan hit 'echo .env)' '区切り )'
u_scan hit 'grep x<.env' '区切り <'
u_scan hit 'echo x>.env' '区切り >'
u_scan hit 'cat ".env"' '区切り "'
u_scan hit "cat '.env'" "区切り '"
u_scan hit 'docker run --env-file=.env x' '区切り ='
u_scan hit 'tar czf a.tgz a.txt,.env' '区切り ,'
u_scan hit 'echo `cat .env`' '区切り `'
u_scan hit 'echo {.env' '区切り {'
u_scan hit 'echo .env}' '区切り }'
u_scan hit 'echo [.env' '区切り ['
u_scan hit 'echo .env]' '区切り ]'
u_scan hit $'cat\t.env' '区切り タブ'
u_scan hit $'cat .env\r' '区切り CR'
u_scan hit $'ls\ncat .env' '区切り 改行'
u_scan miss 'cat .env.example' '除外リスト'
# シェルのトークンでは、$ か . で始まりパスの区切りを含まない語を拡張子で判定しない（変数のプロパティ・jq のパス）
u_scan miss 'echo $cfg.pem' '$cfg.pem（変数のプロパティ）'
u_scan miss "jq '.spec.key'" '.spec.key（jq のパス）'
u_scan hit 'cat ./.spec.key' './.spec.key（パスの区切りを含む）'
u_scan hit 'cat $HOME/.data.key' '$HOME/.data.key（パスの区切りを含む）'
u_scan hit 'cat .env' '.env は . で始まっても名前で判定する'
u_scan hit 'ls .ssh' '.ssh は . で始まってもディレクトリで判定する'
u_scan miss 'ls plugins/credentials-manager' '手掛かりの語を含むが該当しない'
u_scan miss 'echo hello' '手掛かりの語を含まない'
u_scan miss "cat $(rep 'a.env1 ' 256)" '手掛かりの語を含むトークン 256 個（上限ちょうど。通知しない）'
u_scan hit "cat $(rep 'a.env1 ' 257)" '手掛かりの語を含むトークン 257 個（上限を超える。控えめに通知）'
# 16 KB（SCAN_INLINE_MAX）を超えるコマンドは、tr と grep で手掛かりの語を含むトークンだけを取り出す。
# 境界の前後と、区切り文字・大文字小文字・除外・上限の扱いが bash による分割と変わらないこと
printf -v sp '%*s' $((SCAN_INLINE_MAX - 8)) ''
u_scan hit "${sp}cat .env" "長さ $SCAN_INLINE_MAX 文字（bash で分割）の末尾に .env"
u_scan hit " ${sp}cat .env" "長さ $((SCAN_INLINE_MAX + 1)) 文字（tr と grep で分割）の末尾に .env"
printf -v sp '%*s' "$SCAN_INLINE_MAX" ''
for sep in ';' '|' '&' '(' ')' '<' '>' '"' "'" '=' ',' '`' '{' '}' '[' ']' $'\t' $'\r'; do
  u_scan hit "${sp}cat${sep}.env${sep}x" "16 KB 超・区切り $(printf '%q' "$sep")"
done
u_scan hit "${sp}cat .ENV" '16 KB 超・大文字の .ENV'
u_scan hit "$(yes x 2>/dev/null | head -n 9000)"$'\n''cat .env' '16 KB 超・改行の多いコマンドの末尾に .env'
u_scan miss "${sp}cat .env.example" '16 KB 超・除外リスト'
u_scan miss "${sp}ls plugins/credentials-manager" '16 KB 超・手掛かりの語を含むが該当しない'
u_scan miss "${sp}echo hello" '16 KB 超・手掛かりの語を含まない'
u_scan miss "${sp}cat $(rep 'a.env1 ' 256)" '16 KB 超・手掛かりの語を含むトークン 256 個（上限ちょうど）'
u_scan hit "${sp}cat $(rep 'a.env1 ' 257)" '16 KB 超・手掛かりの語を含むトークン 257 個（上限を超える）'

echo "=== 22. 単体: 波括弧の展開（Grep の glob・Glob の pattern） ==="
u_braces() {  # $1=パターン $2=期待する候補（空白区切り。OVERFLOW なら上限超え）
  local got
  cred_expand_braces "$1"
  if [[ -n $CF_BRACE_OVERFLOW ]]; then got=OVERFLOW; else got="${CF_CANDIDATES[*]}"; fi
  if [[ $got == "$2" ]]; then record PASS "展開: $1 → $got"; else record FAIL "展開: $1 （期待: $2 / 実際: $got）"; fi
}
u_braces '*.{pem,key}' '*.pem *.key'
u_braces '**/{.env,*.pem}' '**/.env **/*.pem'
u_braces 'a{b,c}d{e,f}' 'abde acde abdf acdf'
u_braces 'x{a,}' 'xa x'
u_braces 'x{,a}' 'x xa'
u_braces '{a,{b,c}}' 'a b a c'
u_braces 'no-braces' 'no-braces'
u_braces '{single}' '{single}'
u_braces "{$(rep 'a,' 62)b}" "$(rep 'a ' 62)b"
u_braces "{$(rep 'a,' 63)b}" 'OVERFLOW'
u_pattern() {  # $1=期待 $2=パターン $3=表示名
  local got=miss
  credential_pattern_reason "$2"
  [[ -n $CF_REASON ]] && got=hit
  u_check "$1" "$got" "$3"
}
u_pattern hit '{app,}.env' '{app,}.env（空の候補で .env になる）'
u_pattern hit '.env{.local,}' '.env{.local,}'
u_pattern miss '{app,web}.config' '{app,web}.config（どの候補も該当しない）'
u_pattern hit "{$(rep 'a,' 63)b}" '候補が上限を超える（控えめに通知）'

echo
printf '結果: PASS=%s FAIL=%s（既知の制約 %s 件のうち挙動が変わったもの %s 件）\n' "$pass" "$fail" "$known" "$changed"
[[ "$fail" -eq 0 ]]
