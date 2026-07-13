#!/usr/bin/env bash
# get_tasks.sh - シートの WBS ノード（タスクツリー）を取得
#
# 使い方:
#   PB_TENANT=<tenant> [PB_EMAIL=... PB_PASSWORD=...] \
#     bash "${CLAUDE_SKILL_DIR}/references/scripts/fetch/get_tasks.sh" <WORK_DIR> <WBS_ID>
#
# 引数:
#   WORK_DIR  セッション作業領域（cookies.txt が必要）
#   WBS_ID    対象シートの wbsId（list_sheets.sh の sourceId。pageId ではない — 落とし穴 #3）
#
# 出力:
#   $WORK_DIR/pb_wbsnodes.json に保存し、パスを stdout に出力
#   JSON 構造: { pathToDisplayRoot, displayRoot: { id, data: {...}, children: [...] }, ranks }
#   - data.type: PACKAGE / MILESTONE / TASK
#   - 日付は epoch ミリ秒。未設定はキー自体が無い（落とし穴: シートにより planned 系が全て無い場合あり）

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください}"
WBS_ID="${2:?エラー: WBS_ID を第2引数に指定してください（list_sheets.sh の sourceId）}"

if ! [[ "$WBS_ID" =~ ^[0-9a-fA-F-]+$ ]]; then
  echo "エラー: WBS_ID が不正です: $WBS_ID" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTFILE="$WORK_DIR/pb_wbsnodes.json"

bash "$SCRIPT_DIR/../auth/with_session.sh" "$WORK_DIR" \
  "/wbs/wbs/node/getWbsNodes?wbsId=${WBS_ID}" \
  "$OUTFILE"
