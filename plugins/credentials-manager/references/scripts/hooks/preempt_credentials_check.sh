#!/usr/bin/env bash
# preempt_credentials_check.sh
#
# credentials-manager プラグインの PreToolUse フック（bash で実装）。
#
# 認証情報のやり取りが発生し得るすべてのツール呼び出しを検出し、
# Claude へ「credentials-reader スキルでの照合・自動マッチを最優先で行うこと」を
# additionalContext で通知する。
#
# 対象のツール名は hooks.json の matcher と下の case 分岐の 2 か所にある。片方だけを
# 変えると検査が働かないため、変更したら tests/test_hooks.sh を実行する。
#
# 設計: フェイルオープン (例外時も exit 0)

set +e

# 前提を欠くときは、保護が外れたことを stderr に 1 行出して終了する（SessionStart のフックも同じ前提を自己診断して知らせる）
if ! command -v jq >/dev/null 2>&1; then
  echo "[credentials-manager] jq が無いため、検査を省略します" >&2
  exit 0
fi
if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "[credentials-manager] bash 4 以上が必要なため、検査を省略します（${BASH_VERSION:-?}）" >&2
  exit 0
fi

# 秘密情報のパターン（UserPromptSubmit のフックと共有する）と、認証情報系ファイルの判定
hooks_dir="${BASH_SOURCE[0]%/*}"
[[ $hooks_dir == "${BASH_SOURCE[0]}" ]] && hooks_dir=.
for lib in credential_patterns.sh credential_files.sh; do
  # shellcheck source=/dev/null
  if ! source "$hooks_dir/lib/$lib" 2>/dev/null; then
    echo "[credentials-manager] lib/$lib を読み込めないため、検査を省略します" >&2
    exit 0
  fi
done

stdin="$(cat)"
# 空白以外の文字が無ければ終了する。"${stdin//[[:space:]]/}" で空白を除去する判定は、空白の多い大きな入力
# （インデント付きの Write 等）で入力長の二乗の時間がかかり、hooks.json の timeout を超えて検査が無言で欠落するため使わない
if [[ ! $stdin =~ [^[:space:]] ]]; then
  exit 0
fi

# JSON 解析
tool_name="$(printf '%s' "$stdin" | jq -er '.tool_name // empty' 2>/dev/null)"
if [[ -z "$tool_name" ]]; then
  exit 0
fi

reason=""
set_reason() {
  if [[ -z "$reason" ]]; then
    reason="$1"
  fi
}

# シェル系ツール（Bash / PowerShell）の照合ヘルパー。grep を起動せず bash 組み込みの正規表現で照合する
# （Git Bash では grep の起動 1 回に約 50 ms かかり、フックはシェルの全呼び出しで動くため）
match()   { [[ $1 =~ $2 ]]; }
match_i() { local rc; shopt -s nocasematch; [[ $1 =~ $2 ]]; rc=$?; shopt -u nocasematch; return "$rc"; }
CLI_NAMES='curl|wget|http|httpie|aria2c|scp|sftp|ssh|rsync|gh|az|aws|gcloud|kubectl|doctl|heroku|firebase|vercel|netlify|docker|podman|psql|mysql|mongosh|mongo|redis-cli|terraform|tofu|ansible|ansible-playbook|helm|pulumi|packer|vault|op|bw'
CRED_KW='TOKEN|KEY|SECRET|PASSWORD|PASSWD|API|AUTH|CREDENTIAL|SESSION|BEARER|PRIVATE'
CRED_NAME='[A-Za-z0-9_]*('"$CRED_KW"')'   # 認証情報キーワードを含む変数名（先頭からキーワードまで）
# 照合に使う文字クラス（POSIX ERE の角括弧式。角括弧の中の \ は文字そのものを表す）
Q=$'["\']'                                # 引用符
NL=$'\n'
SH_LEAD='[[:space:];|&(`]'                 # コマンド名の直前に来る文字（空白・区切り・括弧）
PS_LEAD=$'[[:space:];|&(`{="\']'          # PowerShell ではさらに { = と引用符（{irm ...} / $r=irm ... / & 'irm'）
PS_PATH_LEAD=$'[[:space:];|&(`{="\'\\/]'  # CLI 名ではさらにパス区切り（C:\...\gh.exe / .\gh.exe / C:/Tools/gh.exe）

# 通知文に入れるツール名（mcp__ のツール名はサーバの設定で決まるため、ファイル名と同じく無害化する）
cred_display_name "$tool_name" 64
tool_shown=$CRED_SHOWN

# 入力が CRED_INPUT_MAX（4 MB）を超える場合は、中身を照合すると timeout（10 秒）近くかかるため、照合せずに控えめに通知する
dispatch=$tool_name
if (( ${#stdin} > CRED_INPUT_MAX )); then
  set_reason "$tool_shown の入力が 4 MB を超え、全体を照合できない"
  dispatch=""
fi

case "$dispatch" in
  WebFetch|WebSearch)
    set_reason "外部 URL アクセスツール ($tool_name) の呼び出し"
    ;;
  mcp__*)
    set_reason "MCP サーバ呼び出し ($tool_shown)"
    ;;
  Bash|PowerShell)
    cmd="$(printf '%s' "$stdin" | jq -er '.tool_input.command // empty' 2>/dev/null)"
    # 照合するのは先頭 CRED_SCAN_MAX 文字（256 KB）まで（下の照合は bash の [[ =~ ]] で、巨大なコマンドでは timeout 近くかかる）。
    # それより長いコマンドは、先頭で何も見つからなければ、残りを判定できないものとして控えめに通知する（末尾に置いた curl 等を見逃さない）
    cmd_len=${#cmd}
    cmd=${cmd:0:CRED_SCAN_MAX}
    if [[ -n "$cmd" ]]; then
      # 外部通信 / IaC / シークレット管理 CLI（Windows では curl.exe・az.cmd のように拡張子付きでも呼ばれる）
      ext_cmd_pattern='(^|'"$SH_LEAD"')('"$CLI_NAMES"')(\.exe|\.cmd)?([[:space:]]|$)'
      # PowerShell ではコマンド名の大文字小文字を区別せず、パス付き・引用符付き・代入（$u=gh ...）・
      # スクリプトブロック（{gh ...}）の中でも呼ばれる
      ps_ext_pattern='(^|'"$PS_PATH_LEAD"')('"$CLI_NAMES"')(\.exe|\.cmd)?([[:space:]]|'"$Q"'|$)'
      if match "$cmd" "$ext_cmd_pattern" || { [[ $tool_name == PowerShell ]] && match_i "$cmd" "$ps_ext_pattern"; }; then
        set_reason "$tool_name で外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI を実行"
      fi
      # PowerShell 系の外部通信（大文字小文字を区別しない）。別名の irm / iwr はコマンドの位置にあるものを対象にし、
      # 直後には空白・括弧・引用符・行末を許す（irm https://... / irm('...') / & 'irm' ...）
      ps_cmd_pattern='(invoke-webrequest|invoke-restmethod|start-bitstransfer|net\.webclient|net\.http\.httpclient|\[(system\.)?net\.webrequest\]|(^|'"$PS_LEAD"')(iwr|irm)([[:space:](]|'"$Q"'|$))'
      if match_i "$cmd" "$ps_cmd_pattern"; then
        if [[ $tool_name == PowerShell ]]; then
          set_reason 'PowerShell で外部通信コマンド（Invoke-WebRequest 等）を実行'
        else
          set_reason 'Bash で PowerShell 系外部通信コマンドを実行'
        fi
      fi
      # 環境変数の設定は、変数名に認証情報キーワードを含む場合のみ検出する（キーワードを任意にすると、
      # MSYS_NO_PATHCONV や PATH など無関係な export / set まで検出してしまう）。
      # 設定は 1 行で完結するため、照合は改行をまたがない（[[:blank:]] は空白とタブのみ）
      env_set_pattern='(^|'"$SH_LEAD"')(export|set)[[:blank:]]+'"$CRED_NAME"'[A-Za-z0-9_]*='
      # PowerShell / Windows の環境変数設定（大文字小文字を区別しない）。値の参照（$env:NAME を読むだけ）は検出しない。
      # Bash から pwsh -c で実行する場合も対象
      ps_env_assign='\$\{?env:'"$CRED_NAME"'[A-Za-z0-9_]*\}?[[:blank:]]*\+?='                          # $env:NAME = ... / ${env:NAME} += ...
      ps_env_dotnet='\[(system\.)?environment\]::setenvironmentvariable\([[:space:]]*'"$Q"'?'"$CRED_NAME"  # [Environment]::SetEnvironmentVariable('NAME', ...)
      # Set-Item -Path Env:NAME / si Env:NAME / New-Item -Path Env: -Name NAME。コマンド名の直後は空白に限り（single 等の語頭に一致させない）、
      # Env: までの引数は 100 文字までにする（上限が無いと、Linux（glibc）の照合で区切りの無い長い行に入力長の二乗の時間がかかる）
      ps_env_provider='((set|new)-(item|itemproperty|content)|(^|'"$PS_LEAD"')(si|ni))[[:blank:]]([^;|&'"$NL"']{0,100}[[:blank:]])?'"$Q"'?env:[\/]?[[:blank:]]*(-name[[:blank:]]+)?'"$Q"'?'"$CRED_NAME"
      ps_env_setx='(^|'"$SH_LEAD"')setx([[:blank:]]+/m)?[[:blank:]]+'"$Q"'?'"$CRED_NAME"                # setx NAME ... / setx /M NAME ...
      ps_env_pattern="($ps_env_assign|$ps_env_dotnet|$ps_env_provider|$ps_env_setx)"
      if match "$cmd" "$env_set_pattern" || match_i "$cmd" "$ps_env_pattern"; then
        set_reason "$tool_name で認証情報らしい環境変数を設定"
      fi
      if cred_find_secret "$cmd"; then
        cred_reason "$tool_name コマンドに"
        set_reason "$CRED_REASON"
      fi
      # 認証情報系ファイルの操作（cat .env / Get-Content ~/.aws/credentials / cp .env.example .env 等）。
      # ファイル系ツールと同じ判定を、コマンドのトークンごとに行う（lib/credential_files.sh）
      # PowerShell では $_.Key 等の変数のプロパティを拡張子で判定しない（Bash の $name.pem はファイル名として判定する）
      scan_mode=shell
      [[ $tool_name == PowerShell ]] && scan_mode=pwsh
      if [[ -z "$reason" ]] && cred_scan_command_files "$cmd" "$scan_mode"; then
        CRED_LABEL=$CF_REASON
        cred_reason "$tool_name で"
        set_reason "$CRED_REASON"
      fi
      if (( cmd_len > CRED_SCAN_MAX )); then
        set_reason "$tool_name で長さが 256 KB を超え、全体を照合できないコマンドを実行"
      fi
    fi
    ;;
  Read|Write|Edit|MultiEdit|NotebookEdit)
    # パス（NotebookEdit は notebook_path）と、照合するコンテンツを 1 回の jq で取り出す（1 行目がパス、2 行目以降がコンテンツ）。
    # コンテンツは tool_input の文字列（内容・置換の前後・パス）だけにする。入力 JSON 全体を照合すると、
    # cwd や transcript_path 等のメタデータに含まれる語にも一致し、JSON のエスケープ（\n 等）でパターンの境界も崩れるため。
    # 受け取りはコマンド置換で行う（read -d は 1 バイトずつ読むため、数 MB の書き込みで数秒かかる）。
    # パスは 1 行にするため改行・NUL を空白にする。jq の gsub は入力長の二乗の時間がかかるため、判定に要る先頭 4097 文字に限って掛ける
    # （4 KB を超えるパスは中身を判定しない）。コンテンツの NUL はコマンド置換が取り除く（bash が stderr に警告を出すだけで照合は途切れない）
    extracted="$(printf '%s' "$stdin" | jq -r '((.tool_input.file_path // .tool_input.notebook_path // "") | tostring | .[0:4097] | gsub("[\r\n\u0000]"; " ")), ([.tool_input | .. | strings] | join("\n"))' 2>/dev/null)"
    file_path=${extracted%%$'\n'*}
    content=${extracted:${#file_path}+1}
    file_path=${file_path%$'\r'}
    if [[ -n "$file_path" ]]; then
      credential_file_reason "$file_path"
      if [[ -n "$CF_REASON" ]]; then
        set_reason "$CF_REASON"
      fi
    fi
    if [[ "$tool_name" != "Read" && -z "$reason" ]]; then
      if cred_find_secret "$content"; then
        cred_reason "$tool_name のコンテンツに"
        set_reason "$CRED_REASON"
      fi
    fi
    ;;
  Grep|Glob)
    # Grep は該当ファイルの内容を出力する。Glob はファイル名の一覧だけだが、認証情報系ファイルを探す操作として扱う。
    # 判定するのはパス（path）とファイル名のパターン（Grep の glob、Glob の pattern）。Grep の pattern は検索する正規表現なので対象外。
    # パターンの波括弧（**/{.env,*.pem}）は展開して判定する
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      credential_pattern_reason "$target"
      if [[ -n "$CF_REASON" ]]; then
        CRED_LABEL=$CF_REASON
        cred_reason "$tool_name で"
        set_reason "$CRED_REASON"
        break
      fi
    done < <(printf '%s' "$stdin" | jq -r 'if .tool_name == "Glob" then [.tool_input.path, .tool_input.pattern] else [.tool_input.path, .tool_input.glob] end | .[] | select(type == "string" and . != "")' 2>/dev/null | tr -d '\r')
    ;;
esac

if [[ -z "$reason" ]]; then
  exit 0
fi

message="[credentials-manager] ${reason}。credentials-reader を最優先起動して保存済み認証情報を照合してください (https でホストが確定する一致1件->自動適用 / 複数件・ホストが確定しない一致・TLS 検証の無効化等->確認 / 0件->保有有無確認)。コマンド・コンテンツに認証情報パターンが含まれる場合はフル値を復唱せずマスク (先頭4+****+末尾4、8文字以下は全マスク****) で扱ってください。書き込み (保存・編集・削除) は credentials-manager に引き継ぎます。詳細: rules/security/credentials-management.md"

jq -nc --arg msg "$message" '{
  continue: true,
  suppressOutput: true,
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  }
}'

exit 0
