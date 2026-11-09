#!/usr/bin/env bash
# test_hooks.sh
#
# credentials-manager の同梱フック（PreToolUse の preempt_credentials_check.sh と
# UserPromptSubmit の detect_credentials_in_prompt.sh）と、hooks.json の登録の回帰テスト。
# 実際のフック入力 JSON を流し、通知の有無・理由文・出力の形式・所要時間を検証する。
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
prompt_timeout_sec=""
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
tk hit Bash 'echo ".env" >> .gitignore' 'Bash: echo ".env" >> .gitignore（.env を無視する設定の追加も、.env を指すトークンとして通知される）'
tk hit Bash "echo \"Basic $(printf '%s%s' Authentication SchemeHandler)\"" 'Bash: echo "Basic <英字だけの 27 文字の識別子>"（Basic の後に 16 文字以上の英数字が続く語は通知される）'

echo "=== 13. UserPromptSubmit: ユーザ入力の秘密情報（case-17・24） ==="
JUDGE_SCRIPT=$PROMPT_HOOK
JUDGE_EVENT=UserPromptSubmit
prompt_json() { jq -cn --arg p "$1" '{prompt: $p}' | tr -d '\r'; }
fake_basic="Basic $(printf '%s' 'demo-user:not-a-real-password' | base64 | tr -d '\r\n')"
printf -v fake_pem '%sBEGIN RSA PRIVATE %s' '-----' 'KEY-----'
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
for kind in secret none; do
  if [[ $kind == secret ]]; then
    json="$({ printf '%s' "$blank"; printf 'key=%s' "$fake_sk"; } | jq -Rsc '{prompt: .}' | tr -d '\r')"
    label='プロンプト: 空白の多い 300 KB の入力（末尾に sk-… のダミー）'
  else
    json="$(printf '%s' "$blank" | jq -Rsc '{prompt: (. + "x")}' | tr -d '\r')"
    label='プロンプト: 空白の多い 300 KB の入力（秘密情報なし）'
  fi
  start=$(now_ms)
  ctx="$(judge "$json")"
  elapsed=$(( $(now_ms) - start ))
  if [[ $ctx == EXIT=* || $ctx == INVALID_OUTPUT ]]; then
    record FAIL "$label （フックの出力が異常: $ctx）"
  elif [[ ($kind == secret && -z $ctx) || ($kind == none && -n $ctx) ]]; then
    record FAIL "$label （判定が期待と異なる: ${ctx:-通知なし}）"
  elif [[ $elapsed -ge $limit_ms ]]; then
    record FAIL "$label （${elapsed} ms / 上限 ${limit_ms} ms）"
  else
    record PASS "$label → ${elapsed} ms"
  fi
done
JUDGE_SCRIPT=""
JUDGE_EVENT=""

echo "=== 14. 秘密情報のパターン（lib/credential_patterns.sh。PreToolUse と UserPromptSubmit で共通） ==="
want='に Basic'
t hit Bash "echo \"Authorization: $fake_basic\"" 'Bash: echo "Authorization: Basic …"（ダミー）'
want='に PEM'
t hit PowerShell "Set-Content key.txt '$fake_pem'" "PowerShell: Set-Content key.txt '<PEM の先頭行>'（ダミー）"
run hit Write "$(jq -cn --arg c "$fake_pem"$'\nMIIE\n' '{tool_name: "Write", tool_input: {file_path: "/repo/id.txt", content: $c}}' | tr -d '\r')" 'Write: コンテンツに PEM の先頭行（ダミー）'
want='認証情報パターン'
run hit Write "$(jq -cn --arg c "line1"$'\n'"$fake_sk" '{tool_name: "Write", tool_input: {file_path: "/repo/a.txt", content: $c}}' | tr -d '\r')" 'Write: 2 行目の行頭に sk-…（JSON のエスケープ \n の直後でも一致する）'
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

echo "=== 15. シェルでの認証情報系ファイルの操作（case-46・47） ==="
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
want=''
t miss Bash "jq -r '.key' data.json" "Bash: jq -r '.key' data.json（語幹の無い .key は対象外）"
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
want=''
limit_ms=$(( ${timeout_sec:-60} * 800 ))
decoys=""
for ((i = 0; i < 20000; i++)); do decoys+='a.env1 '; done
seps=""
for ((i = 0; i < 100000; i++)); do seps+=';'; done
for kind in tokens seps; do
  if [[ $kind == tokens ]]; then
    json="$(printf 'cat %s~/.aws/credentials' "$decoys" | jq -Rsc '{tool_name: "Bash", tool_input: {command: .}}' | tr -d '\r')"
    label='Bash: 手掛かりの語を含むトークン 2 万個の後に ~/.aws/credentials'
  else
    json="$(printf 'echo %s .env' "$seps" | jq -Rsc '{tool_name: "Bash", tool_input: {command: .}}' | tr -d '\r')"
    label='Bash: 区切り文字 10 万個の後に .env'
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
want=''
run miss Grep '{"tool_name":"Grep","tool_input":{"pattern":"sk-[A-Za-z0-9]+","path":"/repo/src"}}' 'Grep: pattern（検索する正規表現）は判定しない'
run miss Grep '{"tool_name":"Grep","tool_input":{"pattern":"TODO","glob":"*.md","path":"/repo"}}' 'Grep: *.md を検索'
run miss Glob '{"tool_name":"Glob","tool_input":{"pattern":"plugins/credentials-manager/**/*.md"}}' 'Glob: plugins/credentials-manager/**/*.md（語の一部の一致では判定しない）'
run miss Glob '{"tool_name":"Glob","tool_input":{"pattern":"**/.env.example"}}' 'Glob: **/.env.example（除外リスト）'
run miss Glob '{"tool_name":"Glob","tool_input":{}}' 'Glob: 入力が空'

echo "=== 17. SessionStart: ルールの配置と自己診断（case-14〜16・25・50） ==="
TEMPLATE="$PLUGIN_ROOT/references/templates/rules/security/credentials-management.md"
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
# 自己診断: jq が無い → 平文で知らせ、配置はしない
session_run "" "$PLUGIN_ROOT" "$TMP_ROOT/project-nojq" /nonexistent
if [[ $SESSION_RC -eq 0 && $SESSION_OUT == *'jq が見つからない'* && ! -e "$TMP_ROOT/project-nojq/.claude" ]]; then
  record PASS '自己診断: jq が無いと、検出フックが動作しないことを平文で知らせる'
else
  record FAIL "自己診断（jq なし）: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:120}"
fi
# 自己診断: 共通のパターン定義が無い → 配置の通知に添えて知らせる
cp -r "$PLUGIN_ROOT" "$TMP_ROOT/nolib"
rm -rf "$TMP_ROOT/nolib/references/scripts/hooks/lib"
session_run "" "$TMP_ROOT/nolib" "$TMP_ROOT/project-nolib"
if [[ $SESSION_RC -eq 0 && "$(session_ctx)" == *'lib/credential_patterns.sh が無い'*配置しました* ]]; then
  record PASS '自己診断: lib/credential_patterns.sh が無いと、配置の通知に添えて知らせる'
else
  record FAIL "自己診断（lib なし）: 終了コード $SESSION_RC / 出力: ${SESSION_OUT:0:120}"
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

echo
printf '結果: PASS=%s FAIL=%s（既知の制約 %s 件のうち挙動が変わったもの %s 件）\n' "$pass" "$fail" "$known" "$changed"
[[ "$fail" -eq 0 ]]
