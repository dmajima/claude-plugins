#!/usr/bin/env bash
# with_session.sh - セッション付き GET 呼び出しラッパ（401 再ログイン + SPA フォールバック検知）
#
# 使い方:
#   PB_TENANT=<tenant> PB_EMAIL=<email> PB_PASSWORD=<password> \
#     bash "${CLAUDE_SKILL_DIR}/scripts/auth/with_session.sh" <WORK_DIR> <API_PATH> <OUTFILE>
#
# 引数:
#   WORK_DIR   cookies.txt があるセッション作業領域
#   API_PATH   /wbs/ から始まる API パス（クエリ含む）。フル URL は受け付けない（SSRF 対策）
#              例: "/wbs/page/loadProjectPages?projectId=xxxx&archiveFilter=ALL"
#   OUTFILE    レスポンス JSON の保存先（$WORK_DIR 配下を推奨）
#
# 環境変数:
#   PB_TENANT             必須。BASE URL の構築に使用
#   PB_EMAIL/PB_PASSWORD  任意。設定されていれば 401 時に自動再ログインする
#
# 横断的関心事（ADR-5）: 401 セッション切れ + 再ログイン + リトライの責務を本スクリプトに集約。
# fetch/*.sh は本スクリプトを呼ぶだけの純粋な API 呼び出し定義に保つ。
#
# 終了コード:
#   0 = 成功（JSON 取得） / 1 = HTTP エラー / 2 = SPA フォールバック検知（HTML が返った）

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください}"
API_PATH="${2:?エラー: API_PATH を第2引数に指定してください（例: /wbs/page/loadProjectPages?...）}"
OUTFILE="${3:?エラー: OUTFILE を第3引数に指定してください}"
: "${PB_TENANT:?エラー: 環境変数 PB_TENANT を設定してください}"

if ! [[ "$PB_TENANT" =~ ^[A-Za-z0-9-]+$ ]]; then
  echo "エラー: PB_TENANT が不正です（英数字とハイフンのみ許可）" >&2
  exit 1
fi
# フル URL・パストラバーサルを拒否し、/wbs/ 配下のみ許可（SSRF 対策）
if ! [[ "$API_PATH" =~ ^/wbs/ ]]; then
  echo "エラー: API_PATH は /wbs/ から始まるパスのみ許可（フル URL 不可）: $API_PATH" >&2
  exit 1
fi

BASE="https://${PB_TENANT}.pm.apps.worksap.com"
COOKIE="$WORK_DIR/cookies.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H=(-H 'Accept: application/json' -H 'X-Requested-With: XMLHttpRequest')

# GET 実行 + HTTP コード取得 + SPA フォールバック検知（落とし穴 #8）
fetch_json() {  # fetch_json <OUTFILE> → stdout に HTTP コード
  local out="$1" code
  code=$(curl -sS --max-time 30 -b "$COOKIE" -c "$COOKIE" "${H[@]}" \
    -o "$out" -w '%{http_code}' "$BASE$API_PATH" || echo "000")
  echo "$code"
}

is_spa_fallback() {  # 200 でも HTML が返るケースの検知
  head -c 200 "$1" | grep -qi '<!DOCTYPE\|<html' 2>/dev/null
}

code=$(fetch_json "$OUTFILE")

# 401: セッション切れ → 再ログインして 1 回だけリトライ
if [ "$code" = "401" ]; then
  if [ -n "${PB_EMAIL:-}" ] && [ -n "${PB_PASSWORD:-}" ]; then
    echo "session expired (401)。再ログインします" >&2
    bash "$SCRIPT_DIR/login.sh" "$WORK_DIR" >&2
    code=$(fetch_json "$OUTFILE")
  else
    echo "ERROR: 401 (セッション切れ)。PB_EMAIL/PB_PASSWORD 未設定のため再ログイン不可" >&2
    exit 1
  fi
fi

if [ "$code" != "200" ]; then
  echo "ERROR: http=$code path=$API_PATH" >&2
  # エラー本文の先頭をダンプする際、Spring Security が HTML に埋め込む CSRF/セッション値をマスクする
  head -c 300 "$OUTFILE" 2>/dev/null | sed -E 's/(XSRF-TOKEN|_csrf|SESSION)[^ <>",;]*/\1=[REDACTED]/gi' >&2 || true
  echo "" >&2
  exit 1
fi

if is_spa_fallback "$OUTFILE"; then
  echo "ERROR: SPA fallback (HTML が返却)。wbsId/パラメータ/セッションを確認してください: $API_PATH" >&2
  exit 2
fi

echo "OK: $OUTFILE"
