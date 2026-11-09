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

# 秘密情報のパターン（UserPromptSubmit のフックと共有する）
hooks_dir="${BASH_SOURCE[0]%/*}"
[[ $hooks_dir == "${BASH_SOURCE[0]}" ]] && hooks_dir=.
# shellcheck source=lib/credential_patterns.sh
if ! source "$hooks_dir/lib/credential_patterns.sh" 2>/dev/null; then
  echo "[credentials-manager] lib/credential_patterns.sh を読み込めないため、検査を省略します" >&2
  exit 0
fi

# 認証情報系ファイルの判定。$1（パス、またはワイルドカードを含むパターン）が該当すれば、
# 通知の理由文を CF_REASON に入れる（該当しなければ空）。
# ファイル系ツールのパス・シェルのコマンド中のトークン・Grep / Glob のパターンで共通に使う。
# サブシェルを起動しないよう、結果は変数で返す（シェルのトークンごとに呼ぶため）
credential_file_reason() {
  CF_REASON=""
  local path="$1"
  [[ -z "$path" ]] && return 0
  # 実在するパスより十分長い文字列は判定しない（下の置換は、区切り文字の多い長い文字列で入力長の二乗の時間がかかる）
  (( ${#path} > 4096 )) && return 0

  local lower="${path//\\/\/}"
  lower="${lower,,}"
  local basename="${lower##*/}"
  # ワイルドカード（.env* / id_rsa* 等）は除いた形で名前を判定する
  local plain="${basename//\*/}"
  plain="${plain//\?/}"

  # .env / .env.* の判定 (example/sample/template/dist/test/spec は除外)
  if [[ "$plain" == ".env" ]]; then
    CF_REASON="環境変数定義ファイル ($basename) を操作"
    return 0
  fi
  if [[ "$plain" == .env.* ]]; then
    case "$plain" in
      .env.example|.env.sample|.env.template|.env.dist|.env.test|.env.spec) ;;
      *)
        CF_REASON="環境変数定義ファイル ($basename) を操作"
        return 0
        ;;
    esac
  fi

  # 完全一致 (ファイル名)。シェルのトークンごとに呼ぶため、ループではなく case で判定する
  case "$plain" in
    credentials.json|credentials.yml|credentials.yaml|credential.json|\
    secrets.json|secrets.yml|secrets.yaml|secret.json|\
    .npmrc|.netrc|.pgpass|.git-credentials|.dockercfg|\
    id_rsa|id_dsa|id_ecdsa|id_ed25519|id_xmss|\
    serviceaccountkey.json|service-account.json|application_default_credentials.json|gcloud-credentials.json|\
    kubeconfig)
      CF_REASON="認証情報を含む可能性が高いファイル ($basename) を操作"
      return 0
      ;;
  esac

  # 拡張子 (秘密鍵 / 証明書)。拡張子の前に 1 文字以上あるものに限る
  # （シェルのコマンドでは、jq のフィルタ '.key' のような語幹の無い語が頻出するため）
  case "$basename" in
    ?*.pem|?*.key|?*.p12|?*.pfx|?*.jks|?*.keystore|?*.crt|?*.cer|?*.der|?*.asc|?*.gpg)
      CF_REASON="秘密鍵 / 証明書らしい拡張子のファイル ($basename) を操作"
      return 0
      ;;
  esac

  # 特殊ディレクトリ配下（ディレクトリそのものを含む。Grep の path やシェルの ls ~/.ssh 等）
  [[ "$lower" =~ (^|/)\.(aws|docker|kube|ssh|gnupg)(/|$) ]] || return 0
  if [[ "$lower" =~ (^|/)\.aws(/(credentials|config)(\.|$)|/?$) ]]; then
    CF_REASON="AWS 認証情報ファイル (~/.aws/...) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.docker(/config\.json($|\.)|/?$) ]]; then
    CF_REASON="Docker 認証ファイル (~/.docker/config.json) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.kube(/config($|\.)|/?$) ]]; then
    CF_REASON="Kubernetes 認証ファイル (~/.kube/config) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.ssh(/|$) ]]; then
    CF_REASON="SSH 鍵格納ディレクトリ (~/.ssh/) のファイルを操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.gnupg(/|$) ]]; then
    CF_REASON="GPG 設定ディレクトリ (~/.gnupg/) のファイルを操作"
    return 0
  fi

  return 0
}

# シェルのコマンド中で認証情報系ファイルを指すトークンを探す手掛かり（大文字小文字を区別しない）。
# これを含まないコマンドはトークンに分けずに済ませる
CRED_FILE_HINT='(\.env|credential|secret|npmrc|netrc|pgpass|dockercfg|id_(rsa|dsa|ecdsa|ed25519|xmss)|serviceaccountkey|service-account|kubeconfig|\.(pem|key|p12|pfx|jks|keystore|crt|cer|der|asc|gpg)|\.aws|\.docker|\.kube|\.ssh|\.gnupg)'
# トークンの区切り（空白・改行・シェルの区切り・括弧・引用符・= ・カンマ）。IFS として使う
SHELL_SEPS=$' \t\n\r;|&()<>"\'=,`{}[]'
# 判定するトークンの上限（手掛かりの語を含むトークンが大量にあるコマンドで、timeout を超えないようにする）
MAX_FILE_TOKENS=256

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

case "$tool_name" in
  WebFetch|WebSearch)
    set_reason "外部 URL アクセスツール ($tool_name) の呼び出し"
    ;;
  mcp__*)
    set_reason "MCP サーバ呼び出し ($tool_name)"
    ;;
  Bash|PowerShell)
    cmd="$(printf '%s' "$stdin" | jq -er '.tool_input.command // empty' 2>/dev/null)"
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
      ps_env_provider='((set|new)-(item|itemproperty|content)|(^|'"$PS_LEAD"')(si|ni))[^;|&'"$NL"']*[[:blank:]]'"$Q"'?env:[\/]?[[:blank:]]*(-name[[:blank:]]+)?'"$Q"'?'"$CRED_NAME"  # Set-Item -Path Env:NAME / si Env:NAME / New-Item -Path Env: -Name NAME
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
      # ファイル系ツールと同じ判定を、コマンドを区切り文字で分けたトークンごとに行う。
      # 分割は IFS による読み取りで行う（置換で区切り文字を空白に変えると、区切り文字の多い大きな入力で二乗の時間がかかる）。
      # 判定するトークンは MAX_FILE_TOKENS 個までとし、超えたら判定を打ち切って控えめに通知する（無言で欠落させない）
      if [[ -z "$reason" ]] && match_i "$cmd" "$CRED_FILE_HINT"; then
        IFS="$SHELL_SEPS" read -r -d '' -a tokens <<< "$cmd"
        candidates=0
        shopt -s nocasematch
        for tok in "${tokens[@]}"; do
          [[ -n "$tok" && "$tok" =~ $CRED_FILE_HINT ]] || continue
          candidates=$((candidates + 1))
          if (( candidates > MAX_FILE_TOKENS )); then
            set_reason "$tool_name で認証情報系ファイルらしい名前を多数含むコマンドを実行"
            break
          fi
          credential_file_reason "$tok"
          if [[ -n "$CF_REASON" ]]; then
            CRED_LABEL=$CF_REASON
            cred_reason "$tool_name で"
            set_reason "$CRED_REASON"
            break
          fi
        done
        shopt -u nocasematch
      fi
    fi
    ;;
  Read|Write|Edit|MultiEdit|NotebookEdit)
    # パス（NotebookEdit は notebook_path）と、照合するコンテンツを 1 回の jq で取り出す（NUL 区切り）。
    # コンテンツは tool_input の文字列（内容・置換の前後・パス）だけにする。入力 JSON 全体を照合すると、
    # cwd や transcript_path 等のメタデータに含まれる語にも一致し、JSON のエスケープ（\n 等）でパターンの境界も崩れるため
    file_path=""
    content=""
    { IFS= read -r -d '' file_path; IFS= read -r -d '' content; } < <(printf '%s' "$stdin" | jq -j '((.tool_input.file_path // .tool_input.notebook_path // "") | tostring), "\u0000", ([.tool_input | .. | strings] | join("\n")), "\u0000"' 2>/dev/null)
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
    # 判定するのはパス（path）とファイル名のパターン（Grep の glob、Glob の pattern）。Grep の pattern は検索する正規表現なので対象外
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      credential_file_reason "$target"
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

message="[credentials-manager] ${reason}。credentials-reader を最優先起動して保存済み認証情報を照合してください (ホストが確定する一致1件->自動適用 / 複数件・ホストが確定しない一致->確認 / 0件->保有有無確認)。コマンド・コンテンツに認証情報パターンが含まれる場合はフル値を復唱せずマスク (先頭4+****+末尾4、8文字以下は全マスク****) で扱ってください。書き込み (保存・編集・削除) は credentials-manager に引き継ぎます。詳細: rules/security/credentials-management.md"

jq -nc --arg msg "$message" '{
  continue: true,
  suppressOutput: true,
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  }
}'

exit 0
