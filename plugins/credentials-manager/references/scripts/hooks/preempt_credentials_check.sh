#!/usr/bin/env bash
# preempt_credentials_check.sh (Bash 版)
#
# credentials-manager プラグインの PreToolUse フック。
#
# 認証情報のやり取りが発生し得るすべてのツール呼び出しを検出し、
# Claude へ「credentials-reader スキルでの照合・自動マッチを最優先で行うこと」を
# additionalContext で通知する。
#
# 設計: フェイルオープン (例外時も exit 0)

set +e

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# 検出パターン
SECRET_PATTERN='(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
BEARER_PATTERN='[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{16,}'

# テスト用のファイルパス判定関数
# 戻り値: 該当する場合は理由文字列を stdout に、該当なしは空
test_credential_file() {
  local path="$1"
  [[ -z "$path" ]] && return 0

  local lower="${path//\\/\/}"
  lower="${lower,,}"
  local basename="${lower##*/}"

  # .env / .env.* の判定 (example/sample/template/dist/test/spec は除外)
  if [[ "$basename" == ".env" ]]; then
    printf '%s' "環境変数定義ファイル ($basename) を操作"
    return 0
  fi
  if [[ "$basename" == .env.* ]]; then
    case "$basename" in
      .env.example|.env.sample|.env.template|.env.dist|.env.test|.env.spec) ;;
      *)
        printf '%s' "環境変数定義ファイル ($basename) を操作"
        return 0
        ;;
    esac
  fi

  # 完全一致 (ファイル名)
  local exact_matches=(
    'credentials.json' 'credentials.yml' 'credentials.yaml' 'credential.json'
    'secrets.json' 'secrets.yml' 'secrets.yaml' 'secret.json'
    '.npmrc' '.netrc' '.pgpass' '.git-credentials' '.dockercfg'
    'id_rsa' 'id_dsa' 'id_ecdsa' 'id_ed25519' 'id_xmss'
    'serviceaccountkey.json' 'service-account.json'
    'application_default_credentials.json'
    'gcloud-credentials.json'
    'kubeconfig'
  )
  local match
  for match in "${exact_matches[@]}"; do
    if [[ "$basename" == "$match" ]]; then
      printf '%s' "認証情報を含む可能性が高いファイル ($basename) を操作"
      return 0
    fi
  done

  # 拡張子 (秘密鍵 / 証明書)
  local secret_extensions=('.pem' '.key' '.p12' '.pfx' '.jks' '.keystore' '.crt' '.cer' '.der' '.asc' '.gpg')
  local ext
  for ext in "${secret_extensions[@]}"; do
    if [[ "$basename" == *"$ext" ]]; then
      printf '%s' "秘密鍵 / 証明書らしい拡張子のファイル ($basename) を操作"
      return 0
    fi
  done

  # 特殊ディレクトリ配下
  if [[ "$lower" =~ (^|/)\.aws/(credentials|config)(\.|$) ]]; then
    printf '%s' "AWS 認証情報ファイル (~/.aws/...) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.docker/config\.json($|\.) ]]; then
    printf '%s' "Docker 認証ファイル (~/.docker/config.json) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.kube/config($|\.) ]]; then
    printf '%s' "Kubernetes 認証ファイル (~/.kube/config) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.ssh/ ]]; then
    printf '%s' "SSH 鍵格納ディレクトリ (~/.ssh/) のファイルを操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.gnupg/ ]]; then
    printf '%s' "GPG 設定ディレクトリ (~/.gnupg/) のファイルを操作"
    return 0
  fi

  return 0
}

stdin="$(cat)"
if [[ -z "${stdin//[[:space:]]/}" ]]; then
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

case "$tool_name" in
  WebFetch|WebSearch)
    set_reason "外部 URL アクセスツール ($tool_name) の呼び出し"
    ;;
  mcp__*)
    set_reason "MCP サーバ呼び出し ($tool_name)"
    ;;
  Bash)
    cmd="$(printf '%s' "$stdin" | jq -er '.tool_input.command // empty' 2>/dev/null)"
    if [[ -n "$cmd" ]]; then
      # 外部通信 / IaC / シークレット管理 CLI
      ext_cmd_pattern='(^|[[:space:];|&(`])(curl|wget|http|httpie|aria2c|scp|sftp|ssh|rsync|gh|az|aws|gcloud|kubectl|doctl|heroku|firebase|vercel|netlify|docker|podman|psql|mysql|mongosh|mongo|redis-cli|terraform|tofu|ansible|ansible-playbook|helm|pulumi|packer|vault|op|bw)([[:space:]]|$)'
      if printf '%s' "$cmd" | grep -qE "$ext_cmd_pattern"; then
        set_reason 'Bash で外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI を実行'
      fi
      ps_cmd_pattern='(Invoke-WebRequest|Invoke-RestMethod|[[:space:];|&(]iwr[[:space:]]|[[:space:];|&(]irm[[:space:]])'
      if printf '%s' "$cmd" | grep -qE "$ps_cmd_pattern"; then
        set_reason 'Bash で PowerShell 系外部通信コマンドを実行'
      fi
      env_set_pattern='(^|[[:space:];&|(`])(export|set)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*((TOKEN|KEY|SECRET|PASSWORD|PASSWD|API|AUTH|CREDENTIAL|SESSION|BEARER|PRIVATE)[A-Za-z0-9_]*)?='
      if printf '%s' "$cmd" | grep -qE "$env_set_pattern"; then
        set_reason 'Bash で認証情報らしい環境変数を設定'
      fi
      if [[ "$cmd" =~ $SECRET_PATTERN ]]; then
        set_reason 'Bash コマンドに認証情報パターンを検出'
      fi
      if printf '%s' "$cmd" | grep -qE "$BEARER_PATTERN"; then
        set_reason 'Bash コマンドに Bearer トークンを検出'
      fi
    fi
    ;;
  Read|Write|Edit|MultiEdit|NotebookEdit)
    file_path="$(printf '%s' "$stdin" | jq -er '.tool_input.file_path // empty' 2>/dev/null)"
    if [[ -n "$file_path" ]]; then
      file_reason="$(test_credential_file "$file_path")"
      if [[ -n "$file_reason" ]]; then
        set_reason "$file_reason"
      fi
    fi
    if [[ "$tool_name" != "Read" && -z "$reason" ]]; then
      if [[ "$stdin" =~ $SECRET_PATTERN ]]; then
        set_reason "$tool_name のコンテンツに認証情報パターンを検出"
      elif printf '%s' "$stdin" | grep -qE "$BEARER_PATTERN"; then
        set_reason "$tool_name のコンテンツに Bearer トークンを検出"
      fi
    fi
    ;;
esac

if [[ -z "$reason" ]]; then
  exit 0
fi

message="[credentials-manager] ${reason}。credentials-reader を最優先起動して保存済み認証情報を照合してください (1件->自動適用 / 複数件->選択 / 0件->保有有無確認)。コマンド・コンテンツに認証情報パターンが含まれる場合はフル値を復唱せずマスク (先頭4+****+末尾4、8文字以下は全マスク****) で扱ってください。書き込み (保存・編集・削除) は credentials-manager に引き継ぎます。詳細: rules/security/credentials-management.md"

jq -nc --arg msg "$message" '{
  continue: true,
  suppressOutput: true,
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  }
}'

exit 0
