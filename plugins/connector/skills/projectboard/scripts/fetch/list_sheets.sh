#!/usr/bin/env bash
# list_sheets.sh - プロジェクトのシート（ページ）一覧を取得
#
# 使い方:
#   PB_TENANT=<tenant> [PB_EMAIL=... PB_PASSWORD=...] \
#     bash "${CLAUDE_SKILL_DIR}/scripts/fetch/list_sheets.sh" <WORK_DIR> <PROJECT_UUID>
#
# 引数:
#   WORK_DIR      セッション作業領域（cookies.txt が必要。事前に login.sh 実行）
#   PROJECT_UUID  プロジェクト ID（UUID 形式。urlKey の場合は先に urlkey.py で変換）
#
# 出力:
#   $WORK_DIR/pb_sheets.json に保存し、パスを stdout に出力
#   JSON 構造: [{ projectId, id(pageId), title(シート名), pageType(ISSUE/DASHBOARD), sourceId(=wbsId), ... }]
#
# 注意: getWbsNodes に渡す wbsId は本レスポンスの sourceId（pageId ではない — 落とし穴 #3）

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください}"
PROJECT_UUID="${2:?エラー: PROJECT_UUID を第2引数に指定してください（UUID 形式）}"

if ! [[ "$PROJECT_UUID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
  echo "エラー: PROJECT_UUID が UUID 形式ではありません: $PROJECT_UUID（urlKey の場合は resolve/urlkey.py で変換）" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTFILE="$WORK_DIR/pb_sheets.json"

bash "$SCRIPT_DIR/../auth/with_session.sh" "$WORK_DIR" \
  "/wbs/page/loadProjectPages?projectId=${PROJECT_UUID}&archiveFilter=ALL" \
  "$OUTFILE"
