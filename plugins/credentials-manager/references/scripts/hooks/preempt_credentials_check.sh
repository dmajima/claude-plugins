#!/usr/bin/env bash
# preempt_credentials_check.sh
#
# credentials-manager プラグインの PreToolUse フック。
# 認証情報のやり取りが発生し得るすべてのツール呼び出しを検出し、
# Claude へ「credentials-reader スキルでの照合・自動マッチを最優先で行うこと」を
# additionalContext で通知する。書き込みが必要な場合のみ credentials-manager に
# 引き継ぐ責務分離設計（参照系：reader / 書き込み系：manager）。
#
# 検出対象:
#   1. 外部通信ツール
#       - WebFetch / WebSearch                       → 常に対象
#       - mcp__*                                      → 常に対象（MCP 経由の外部 API）
#       - Bash + 外部通信コマンド                      → curl / wget / gh / ssh / scp / sftp / rsync /
#                                                       aws / az / gcloud / kubectl / doctl / heroku /
#                                                       firebase / vercel / netlify / docker / Invoke-* / iwr / irm
#       - Bash + 認証付きクライアント                  → psql / mysql / mongosh / mongo / redis-cli
#
#   2. シークレット直接埋め込み
#       - Bash command にシークレットパターンを含む    → sk-* / ghp_* / gho_* / ghu_* / ghs_* / ghr_* /
#                                                       xoxb-* / xoxp-* / xoxa-* / xoxr-* / xoxs-* /
#                                                       AKIA* / AIza* / glpat-* / eyJ*.*.* / Bearer ...
#       - Bash で認証情報らしい環境変数を export/set   → export FOO_TOKEN=...
#       - Write / Edit / MultiEdit / NotebookEdit のコンテンツにシークレットパターン
#
#   3. 認証情報系ファイル操作
#       - Read / Write / Edit / MultiEdit / NotebookEdit が下記ファイルを対象とする場合
#           .env / .env.* （ただし .env.example/.sample/.template/.dist は除外）
#           credentials.json / credentials.yml / credentials.yaml / credential.json
#           secrets.json / secrets.yml / secrets.yaml / secret.json
#           .npmrc / .netrc / .pgpass / .git-credentials / .dockercfg
#           id_rsa / id_dsa / id_ecdsa / id_ed25519 / id_xmss
#           serviceAccountKey.json / service-account.json
#           application_default_credentials.json / gcloud-credentials.json
#           kubeconfig
#           ~/.aws/credentials, ~/.aws/config
#           ~/.docker/config.json
#           ~/.kube/config
#           ~/.ssh/*, ~/.gnupg/*
#           *.pem / *.key / *.p12 / *.pfx / *.jks / *.keystore / *.crt / *.cer / *.der / *.asc / *.gpg
#
# 通知形式:
#   exit 0 + stdout に hookSpecificOutput.additionalContext を含む JSON

set -uo pipefail

INPUT="$(cat)"
# 改行・タブを空白に正規化（grep で扱いやすくする）
INPUT_FLAT="$(printf '%s' "$INPUT" | tr '\n\t' '  ')"

# tool_name 抽出
TOOL_NAME="$(printf '%s' "$INPUT_FLAT" \
  | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]+"' \
  | head -1 \
  | sed -E 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"

if [[ -z "$TOOL_NAME" ]]; then
  exit 0
fi

# シークレットパターン（grep -E）
SECRET_PATTERN='(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
BEARER_PATTERN='[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{16,}'

REASON=""

# 1 件目の検知理由のみ採用（重複通知の抑制）
set_reason() {
  if [[ -z "$REASON" ]]; then
    REASON="$1"
  fi
}

# 認証情報系ファイルパスを判定
detect_credential_file() {
  local path="$1"
  if [[ -z "$path" ]]; then
    return 1
  fi
  # パス区切りを統一し小文字化
  local lower
  lower="$(printf '%s' "$path" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')"
  local basename
  basename="${lower##*/}"

  # .env / .env.* の判定（example/sample/template/dist/test は除外）
  if [[ "$basename" == ".env" ]]; then
    set_reason "環境変数定義ファイル ($basename) を操作"
    return 0
  fi
  if [[ "$basename" == .env.* ]]; then
    case "$basename" in
      .env.example|.env.sample|.env.template|.env.dist|.env.test|.env.spec) ;;
      *) set_reason "環境変数定義ファイル ($basename) を操作"; return 0 ;;
    esac
  fi

  # 完全一致のファイル名
  case "$basename" in
    credentials.json|credentials.yml|credentials.yaml|credential.json|\
    secrets.json|secrets.yml|secrets.yaml|secret.json|\
    .npmrc|.netrc|.pgpass|.git-credentials|.dockercfg|\
    id_rsa|id_dsa|id_ecdsa|id_ed25519|id_xmss|\
    serviceaccountkey.json|service-account.json|\
    application_default_credentials.json|\
    gcloud-credentials.json|\
    kubeconfig)
      set_reason "認証情報を含む可能性が高いファイル ($basename) を操作"
      return 0
      ;;
  esac

  # 拡張子（秘密鍵 / 証明書）
  case "$basename" in
    *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore|*.crt|*.cer|*.der|*.asc|*.gpg)
      set_reason "秘密鍵 / 証明書らしい拡張子のファイル ($basename) を操作"
      return 0
      ;;
  esac

  # 特殊ディレクトリ配下
  if printf '%s' "$lower" | grep -qE '(^|/)\.aws/(credentials|config)(\.|$)'; then
    set_reason "AWS 認証情報ファイル (~/.aws/...) を操作"
    return 0
  fi
  if printf '%s' "$lower" | grep -qE '(^|/)\.docker/config\.json($|\.)'; then
    set_reason "Docker 認証ファイル (~/.docker/config.json) を操作"
    return 0
  fi
  if printf '%s' "$lower" | grep -qE '(^|/)\.kube/config($|\.)'; then
    set_reason "Kubernetes 認証ファイル (~/.kube/config) を操作"
    return 0
  fi
  if printf '%s' "$lower" | grep -qE '(^|/)\.ssh/'; then
    set_reason "SSH 鍵格納ディレクトリ (~/.ssh/) のファイルを操作"
    return 0
  fi
  if printf '%s' "$lower" | grep -qE '(^|/)\.gnupg/'; then
    set_reason "GPG 設定ディレクトリ (~/.gnupg/) のファイルを操作"
    return 0
  fi

  return 1
}

case "$TOOL_NAME" in
  WebFetch|WebSearch)
    set_reason "外部 URL アクセスツール ($TOOL_NAME) の呼び出し"
    ;;
  mcp__*)
    set_reason "MCP サーバ呼び出し ($TOOL_NAME)"
    ;;
  Bash)
    CMD="$(printf '%s' "$INPUT_FLAT" \
      | grep -oE '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
      | head -1 \
      | sed -E 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//')"
    if [[ -n "$CMD" ]]; then
      # 外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI
      if printf '%s' "$CMD" | grep -qiE '(^|[[:space:]]|[;|&(`])(curl|wget|http|httpie|aria2c|scp|sftp|ssh|rsync|gh|az|aws|gcloud|kubectl|doctl|heroku|firebase|vercel|netlify|docker|podman|psql|mysql|mongosh|mongo|redis-cli|terraform|tofu|ansible|ansible-playbook|helm|pulumi|packer|vault|op|bw)([[:space:]]|$)'; then
        set_reason "Bash で外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI を実行"
      fi
      if printf '%s' "$CMD" | grep -qiE '(Invoke-WebRequest|Invoke-RestMethod|[[:space:];|&(]iwr[[:space:]]|[[:space:];|&(]irm[[:space:]])'; then
        set_reason "Bash で PowerShell 系外部通信コマンドを実行"
      fi
      # 認証情報らしい環境変数の設定
      if printf '%s' "$CMD" | grep -qiE '(^|[[:space:];&|(`])(export|set)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*((TOKEN|KEY|SECRET|PASSWORD|PASSWD|API|AUTH|CREDENTIAL|SESSION|BEARER|PRIVATE)[A-Za-z0-9_]*)?='; then
        set_reason "Bash で認証情報らしい環境変数を設定"
      fi
      # シークレットパターン直接埋め込み
      if printf '%s' "$CMD" | grep -qE "$SECRET_PATTERN"; then
        set_reason "Bash コマンドに認証情報パターンを検出"
      fi
      if printf '%s' "$CMD" | grep -qE "$BEARER_PATTERN"; then
        set_reason "Bash コマンドに Bearer トークンを検出"
      fi
    fi
    ;;
  Read|Write|Edit|MultiEdit|NotebookEdit)
    FILE_PATH="$(printf '%s' "$INPUT_FLAT" \
      | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
      | head -1 \
      | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')"
    if [[ -n "$FILE_PATH" ]]; then
      detect_credential_file "$FILE_PATH" || true
    fi

    # 書き込み系ツールではコンテンツ内のシークレットパターンも検出
    if [[ "$TOOL_NAME" != "Read" ]]; then
      if [[ -z "$REASON" ]] && printf '%s' "$INPUT_FLAT" | grep -qE "$SECRET_PATTERN"; then
        set_reason "${TOOL_NAME} のコンテンツに認証情報パターンを検出"
      fi
      if [[ -z "$REASON" ]] && printf '%s' "$INPUT_FLAT" | grep -qE "$BEARER_PATTERN"; then
        set_reason "${TOOL_NAME} のコンテンツに Bearer トークンを検出"
      fi
    fi
    ;;
esac

if [[ -z "$REASON" ]]; then
  exit 0
fi

# JSON 用エスケープ
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

ESCAPED_REASON="$(escape_json "$REASON")"

cat <<EOF
{
  "continue": true,
  "suppressOutput": true,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "[credentials-manager] ${ESCAPED_REASON}。credentials-reader を最優先起動して保存済み認証情報を照合してください（1件→自動適用 / 複数件→選択 / 0件→保有有無確認）。コマンド・コンテンツに認証情報パターンが含まれる場合はフル値を復唱せずマスク（先頭4+****+末尾4、8文字以下は全マスク****）で扱ってください。書き込み（保存・編集・削除）は credentials-manager に引き継ぎます。詳細: rules/security/credentials-management.md"
  }
}
EOF

exit 0
