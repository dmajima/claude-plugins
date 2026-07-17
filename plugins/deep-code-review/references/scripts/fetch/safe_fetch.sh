#!/usr/bin/env bash
set -euo pipefail

# 外部 URL の安全な取得ガード（SSRF 対策をツール層で強制）
#
# code-review-spec-inference が外部資料を取得する際、raw `curl` の代わりに本スクリプト
# 経由でのみ HTTP GET を許すことで、ホワイトリスト・内部 IP 拒否・DNS rebinding 対策・
# サイズ/タイムアウト/リダイレクト上限を allowed-tools（Bash(bash .../fetch/*.sh *)）で強制する。
#
# 規範: ${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md
#
# Usage:
#   safe_fetch.sh <url> <allowed_hosts_csv>
#     <url>               取得対象 URL（https のみ許可）
#     <allowed_hosts_csv> credentials.json 等で許可されたホスト名のカンマ区切りホワイトリスト
#
# Exit: 0=成功（本文を stdout）, 1=拒否/失敗（理由を stderr）
# 認証情報はコマンドライン引数に載せない（呼び出し側が netrc 等で付与する場合も本スクリプトは
# ヘッダ・認証を一切付けず、公開資料の取得のみを担う）。

URL="${1:?Usage: safe_fetch.sh <url> <allowed_hosts_csv>}"
ALLOWED_CSV="${2:?Usage: safe_fetch.sh <url> <allowed_hosts_csv>}"

# 1. スキーム検証（https のみ）
case "$URL" in
  https://*) : ;;
  *) echo "ERROR: https スキームのみ許可されます: $URL" >&2; exit 1 ;;
esac

# 2. ホスト抽出（ASCII 限定・ポート分離）
HOSTPORT="${URL#https://}"; HOSTPORT="${HOSTPORT%%/*}"
HOST="${HOSTPORT%%:*}"
PORT="${HOSTPORT##*:}"; [ "$PORT" = "$HOSTPORT" ] && PORT=443
if ! printf '%s' "$HOST" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$'; then
  echo "ERROR: 不正なホスト名（ASCII 英数字・ドット・ハイフンのみ許可）: $HOST" >&2; exit 1
fi
if printf '%s' "$HOST" | grep -qF '..'; then
  echo "ERROR: ホスト名に連続ドットが含まれます: $HOST" >&2; exit 1
fi

# 3. ホワイトリスト照合（完全一致）
MATCHED=0
IFS=',' read -ra ALLOWED <<< "$ALLOWED_CSV"
for h in "${ALLOWED[@]}"; do
  h="$(printf '%s' "$h" | tr -d '[:space:]')"
  [ -n "$h" ] && [ "$HOST" = "$h" ] && MATCHED=1 && break
done
if [ "$MATCHED" -ne 1 ]; then
  echo "ERROR: $HOST はホワイトリストに未登録のため取得しません（safe-external-fetch.md セクション 1.2）" >&2; exit 1
fi

# 4. 名前解決
IPS=""
if command -v getent > /dev/null 2>&1; then
  IPS=$(getent ahosts "$HOST" 2>/dev/null | awk '{print $1}' | sort -u)
elif command -v nslookup > /dev/null 2>&1; then
  IPS=$(nslookup "$HOST" 2>/dev/null | awk '/^Address/ && !/#/ {print $NF}')
fi
if [ -z "$IPS" ]; then
  echo "ERROR: $HOST の名前解決に失敗しました" >&2; exit 1
fi

# 5. 内部 IP / IMDS 拒否（0.0.0.0/8・ループバック・私設・リンクローカル・IMDS・IPv4-mapped IPv6・ULA fc00::/7）
DENY_REGEX='^(0\.|127\.|10\.|192\.168\.|169\.254\.|::1$|::ffff:|fe80:|f[cd][0-9a-f][0-9a-f]:|172\.(1[6-9]|2[0-9]|3[01])\.)'
PIN_IP=""
for ip in $IPS; do
  if printf '%s' "$ip" | grep -Eq "$DENY_REGEX"; then
    echo "ERROR: $HOST → $ip は拒否範囲に含まれます（内部 IP / IMDS）" >&2; exit 1
  fi
  [ -z "$PIN_IP" ] && PIN_IP="$ip"
done

# 6. DNS rebinding 対策で照合済み IP をピン留めし、サイズ/タイムアウト/リダイレクト上限付きで取得
curl -sS \
  --resolve "${HOST}:${PORT}:${PIN_IP}" \
  --proto '=https' \
  --max-time 30 \
  --max-filesize 1048576 \
  -L --max-redirs 3 \
  "$URL"
