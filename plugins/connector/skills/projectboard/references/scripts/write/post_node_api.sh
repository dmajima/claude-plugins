#!/usr/bin/env bash
# post_node_api.sh - WBS ノード書き込み API（POST）の共通呼び出しラッパ
#
# 使い方:
#   PB_TENANT=<tenant> [PB_EMAIL=... PB_PASSWORD=...] \
#     bash "${CLAUDE_SKILL_DIR}/references/scripts/write/post_node_api.sh" <WORK_DIR> <API_NAME> <BODY_FILE>
#
# 引数:
#   WORK_DIR   セッション作業領域（cookies.txt が必要。事前に login.sh 実行）
#   API_NAME   呼び出す API 名（下記ホワイトリストのみ許可）
#   BODY_FILE  JSON リクエストボディのファイルパス（jq 等で構築したもの）
#
# 許可 API（base: /wbs/wbs/node/ — 読み取りの getWbsNodes と同一 base。POST を /wbs/project/node/ とする旧記述は誤り。落とし穴 #4）:
#   addNode                  ノード（タスク/パッケージ/マイルストーン）新規作成
#   updateNodeContent        ノードのフィールド更新
#   moveNode                 ノード移動（親変更・並べ替え）
#   moveNodeUpOrDown         兄弟内で上下移動
#   deleteNode               ノード削除
#   reverseWbsNodeActivity   操作の取り消し（operationId 単位の Undo）
#
# 出力:
#   $WORK_DIR/pb_write_response.json に保存し、パスを stdout に出力
#
# CSRF: POST には X-XSRF-TOKEN ヘッダが必須（落とし穴 #6）。
#   XSRF-TOKEN Cookie が cookie jar に無い場合は任意 GET で発行させてから読み取る。
#
# 終了コード:
#   0 = 成功 / 1 = HTTP エラー / 2 = SPA フォールバック検知 / 3 = 引数エラー

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください}"
API_NAME="${2:?エラー: API_NAME を第2引数に指定してください}"
BODY_FILE="${3:?エラー: BODY_FILE を第3引数に指定してください}"
: "${PB_TENANT:?エラー: 環境変数 PB_TENANT を設定してください}"

if ! [[ "$PB_TENANT" =~ ^[A-Za-z0-9-]+$ ]]; then
  echo "エラー: PB_TENANT が不正です（英数字とハイフンのみ許可）" >&2
  exit 3
fi

# API 名ホワイトリスト（任意エンドポイントへの POST を防ぐ）
case "$API_NAME" in
  addNode|updateNodeContent|moveNode|moveNodeUpOrDown|deleteNode|reverseWbsNodeActivity) ;;
  *)
    echo "エラー: 許可されていない API 名です: $API_NAME" >&2
    exit 3
    ;;
esac

if [ ! -f "$BODY_FILE" ]; then
  echo "エラー: BODY_FILE が存在しません: $BODY_FILE" >&2
  exit 3
fi
# BODY_FILE が WORK_DIR 配下であることを確認（パストラバーサルで任意ファイルを送信する事故を防止）
BODY_FILE_REAL=$(realpath "$BODY_FILE" 2>/dev/null) || { echo "エラー: BODY_FILE のパス解決に失敗: $BODY_FILE" >&2; exit 3; }
WORK_DIR_REAL=$(realpath "$WORK_DIR" 2>/dev/null) || { echo "エラー: WORK_DIR のパス解決に失敗: $WORK_DIR" >&2; exit 3; }
case "$BODY_FILE_REAL" in
  "$WORK_DIR_REAL"/*) ;;
  *)
    echo "エラー: BODY_FILE は WORK_DIR 配下に配置してください: $BODY_FILE" >&2
    exit 3
    ;;
esac
# ボディが妥当な JSON であることを送信前に検証
if ! jq -e . "$BODY_FILE" > /dev/null 2>&1; then
  echo "エラー: BODY_FILE が妥当な JSON ではありません: $BODY_FILE" >&2
  exit 3
fi

# stomp_session.py 経由で呼ばれた場合、PB_CONNECTION_ID（生きた WebSocket セッションの
# connectionId）をボディの connectionId に注入する。さらに operationId は
# 「connectionId + 単調増加カウンタ」形式が必須のため（JS: operationId=wbsWebSocketId.concat(counter)）、
# ボディの operationId をこの形式で再生成する。
if [ -n "${PB_CONNECTION_ID:-}" ]; then
  if [[ "$PB_CONNECTION_ID" =~ ^[A-Za-z0-9]+$ ]]; then
    # connectionId + epoch ミリ秒（単調増加・ユニーク）を operationId にする
    op_id="${PB_CONNECTION_ID}$(date +%s%N | cut -c1-13)"
    tmp_injected="$WORK_DIR/pb_body_injected.json"
    jq --arg conn "$PB_CONNECTION_ID" --arg op "$op_id" \
      '.connectionId = $conn | .operationId = $op' "$BODY_FILE" > "$tmp_injected" \
      && chmod 600 "$tmp_injected" && BODY_FILE="$tmp_injected"
  else
    echo "エラー: PB_CONNECTION_ID が不正です" >&2
    exit 3
  fi
fi

BASE="https://${PB_TENANT}.pm.apps.worksap.com"
COOKIE="$WORK_DIR/cookies.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTFILE="$WORK_DIR/pb_write_response.json"
H=(-H 'Accept: application/json' -H 'X-Requested-With: XMLHttpRequest' -H 'Content-Type: application/json')

# cookie jar から XSRF-TOKEN を抽出し、形式検証（ヘッダインジェクション・破損 jar 対策）して返す
read_xsrf_from_jar() {
  local token
  token=$(grep -i 'XSRF-TOKEN' "$COOKIE" 2>/dev/null | tail -n 1 | awk '{print $NF}') || true
  if [[ "${token:-}" =~ ^[A-Za-z0-9._=-]+$ ]]; then
    printf '%s' "$token"
  fi
}

# 任意 GET で XSRF-TOKEN を発行・更新させる（/wbs/account/getLoginUserInfo は 404 を返すが Set-Cookie する）
refresh_xsrf() {
  curl -sS --max-time 30 -b "$COOKIE" -c "$COOKIE" "${H[@]:0:4}" \
    "$BASE/wbs/account/getLoginUserInfo" -o /dev/null || true
  read_xsrf_from_jar
}

# XSRF-TOKEN を cookie jar から読む。無ければ GET で発行させる
get_xsrf() {
  local token
  token=$(read_xsrf_from_jar)
  if [ -z "${token:-}" ]; then
    token=$(refresh_xsrf)
  fi
  printf '%s' "${token:-}"
}

# curl.exe（Windows ネイティブ）は POSIX パスを「@file」埋め込み形式では解釈できないため変換する
to_curl_path() {
  if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

post_once() {  # stdout に HTTP コード
  local xsrf="$1" code
  code=$(curl -sS --max-time 30 -b "$COOKIE" -c "$COOKIE" "${H[@]}" \
    -H "X-XSRF-TOKEN: ${xsrf}" \
    -X POST --data-binary @"$(to_curl_path "$BODY_FILE")" \
    -o "$OUTFILE" -w '%{http_code}' \
    "$BASE/wbs/wbs/node/${API_NAME}" || echo "000")
  echo "$code"
}

XSRF=$(get_xsrf)
if [ -z "$XSRF" ]; then
  echo "エラー: XSRF-TOKEN を取得できません。ログイン状態を確認してください" >&2
  exit 1
fi

code=$(post_once "$XSRF")

# 401: セッション切れ → 再ログイン + XSRF 再取得 → 1 回リトライ
if [ "$code" = "401" ]; then
  if [ -n "${PB_EMAIL:-}" ] && [ -n "${PB_PASSWORD:-}" ]; then
    echo "session expired (401)。再ログインします" >&2
    bash "$SCRIPT_DIR/../auth/login.sh" "$WORK_DIR" >&2
    XSRF=$(get_xsrf)
    code=$(post_once "$XSRF")
  else
    echo "ERROR: 401 (セッション切れ)。PB_EMAIL/PB_PASSWORD 未設定のため再ログイン不可" >&2
    exit 1
  fi
fi

# 403: CSRF トークン不整合 → 強制 GET でトークンを更新（jar 内の失効値を使い回さない）→ 1 回リトライ
if [ "$code" = "403" ]; then
  echo "403 (CSRF)。XSRF-TOKEN を強制再取得してリトライします" >&2
  XSRF=$(refresh_xsrf)
  if [ -z "$XSRF" ]; then
    echo "エラー: XSRF-TOKEN を再取得できません" >&2
    exit 1
  fi
  code=$(post_once "$XSRF")
fi

if [ "$code" != "200" ]; then
  echo "ERROR: http=$code api=$API_NAME" >&2
  # エラー本文の先頭をダンプする際、CSRF/セッション値をマスクする
  head -c 500 "$OUTFILE" 2>/dev/null | sed -E 's/(XSRF-TOKEN|_csrf|SESSION)[^ <>",;]*/\1=[REDACTED]/gi' >&2 || true
  echo "" >&2
  exit 1
fi

if head -c 200 "$OUTFILE" | grep -qi '<!DOCTYPE\|<html' 2>/dev/null; then
  echo "ERROR: SPA fallback (HTML が返却)。パラメータ/ボディ構造を確認してください: $API_NAME" >&2
  exit 2
fi

echo "OK: $OUTFILE"
