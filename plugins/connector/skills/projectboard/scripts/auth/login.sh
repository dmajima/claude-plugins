#!/usr/bin/env bash
# login.sh - HUE ProjectBoard へのフォームログイン（Cookie セッション確立）
#
# 使い方:
#   PB_TENANT=<tenant> PB_EMAIL=<email> PB_PASSWORD=<password> \
#     bash "${CLAUDE_SKILL_DIR}/scripts/auth/login.sh" <WORK_DIR>
#
# 引数:
#   WORK_DIR      Cookie jar (cookies.txt) を生成するセッション作業領域
#
# 環境変数（必須）:
#   PB_TENANT     テナント識別子（例: example-tenant）。英数字のみ
#   PB_EMAIL      ログインメールアドレス
#   PB_PASSWORD   パスワード
#
# セキュリティ設計（safe-api-access.md 準拠）:
#   - パスワードはコマンドライン引数で受け取らない（ps で露出するため環境変数渡し）
#   - curl へは一時ファイル (--data-urlencode "password@file") 経由で渡す
#   - 一時ファイルは trap で確実に削除し、環境変数はログイン後 unset する
#   - Cookie 値・パスワードを標準出力・標準エラーに出さない
#
# 終了コード:
#   0 = ログイン成功 / 1 = 認証失敗(badCredentials) / 2 = 引数・前提エラー / 3 = SSO 等で形式不一致

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください}"
: "${PB_TENANT:?エラー: 環境変数 PB_TENANT を設定してください（例: example-tenant）}"
: "${PB_EMAIL:?エラー: 環境変数 PB_EMAIL を設定してください}"
: "${PB_PASSWORD:?エラー: 環境変数 PB_PASSWORD を設定してください}"

# テナントのバリデーション（ホスト名インジェクション対策）
if ! [[ "$PB_TENANT" =~ ^[A-Za-z0-9-]+$ ]]; then
  echo "エラー: PB_TENANT が不正です（英数字とハイフンのみ許可）" >&2
  exit 2
fi

mkdir -p "$WORK_DIR"
BASE="https://${PB_TENANT}.pm.apps.worksap.com"
COOKIE="$WORK_DIR/cookies.txt"

# curl.exe（Windows ネイティブ）は POSIX パス（/tmp/...）を「name@file」埋め込み形式では
# 解釈できない（独立引数と異なり MSYS のパス自動変換が効かない）。Git Bash では cygpath で変換する
to_curl_path() {
  if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

# 認証値の一時ファイル（コマンドライン露出防止）
USERFILE=""; PWFILE=""
cleanup() { rm -f "${USERFILE:-}" "${PWFILE:-}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM HUP QUIT
USERFILE=$(mktemp); chmod 600 "$USERFILE"
PWFILE=$(mktemp); chmod 600 "$PWFILE"
printf '%s' "$PB_EMAIL" > "$USERFILE"
printf '%s' "$PB_PASSWORD" > "$PWFILE"
unset PB_PASSWORD   # メモリ上の値を即破棄

# 再ログイン時は旧 SESSION を破棄（セッション固定対策）し、
# cookie jar を 600 で先行作成してから curl -c に渡す（umask 依存の 644 生成を防止）
rm -f "$COOKIE"
( umask 077; : > "$COOKIE" )

# 初期 SESSION Cookie の取得
curl -sS --max-time 30 -c "$COOKIE" "$BASE/auth/sign-in" -o /dev/null

# フォームログイン（パラメータ名は username。値はメールアドレス — 落とし穴 #1）
LOC=$(curl -sS --max-time 30 -b "$COOKIE" -c "$COOKIE" -X POST \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "username@$(to_curl_path "$USERFILE")" \
  --data-urlencode "password@$(to_curl_path "$PWFILE")" \
  --data-urlencode '_csrf=' \
  -o /dev/null -w '%{redirect_url}' \
  "$BASE/auth/sign-in")

case "$LOC" in
  *"/wbs/projects/quick"*)
    echo "login: OK (tenant=${PB_TENANT})"
    ;;
  *"error=badCredentials"*)
    echo "login: FAILED (bad credentials)。credentials.json の hue-projectboard エントリを確認してください" >&2
    exit 1
    ;;
  *)
    echo "login: UNEXPECTED redirect（SSO 等への切替の可能性。フォームログイン不可）" >&2
    exit 3
    ;;
esac
