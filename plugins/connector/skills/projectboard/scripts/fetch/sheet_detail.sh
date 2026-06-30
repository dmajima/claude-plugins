#!/usr/bin/env bash
# sheet_detail.sh - シートの詳細（列定義・ステータスセット）を取得
#
# 使い方:
#   PB_TENANT=<tenant> [PB_EMAIL=... PB_PASSWORD=...] \
#     bash "${CLAUDE_SKILL_DIR}/scripts/fetch/sheet_detail.sh" <WORK_DIR> <PROJECT_UUID> <PAGE_ID>
#
# 引数:
#   WORK_DIR      セッション作業領域（cookies.txt が必要）
#   PROJECT_UUID  プロジェクト ID（UUID 形式）
#   PAGE_ID       シートのページ ID（list_sheets.sh の id。sourceId ではない）
#
# 出力:
#   $WORK_DIR/pb_pagedetail.json に保存し、パスを stdout に出力
#   主な内容:
#     - optionalData.code            シートコード（URL の sheetCode と突合）
#     - optionalData.linkedNodeFields  列定義（CSV 全列モードのスキーマソース — ADR-8）
#     - optionalData.statusSet       ステータス定義（ステータス名 → id の解決に使用）

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください}"
PROJECT_UUID="${2:?エラー: PROJECT_UUID を第2引数に指定してください（UUID 形式）}"
PAGE_ID="${3:?エラー: PAGE_ID を第3引数に指定してください}"

if ! [[ "$PROJECT_UUID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
  echo "エラー: PROJECT_UUID が UUID 形式ではありません: $PROJECT_UUID" >&2
  exit 1
fi
if ! [[ "$PAGE_ID" =~ ^[0-9a-fA-F-]+$ ]]; then
  echo "エラー: PAGE_ID が不正です: $PAGE_ID" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTFILE="$WORK_DIR/pb_pagedetail.json"

bash "$SCRIPT_DIR/../auth/with_session.sh" "$WORK_DIR" \
  "/wbs/page/getPageDetail?projectId=${PROJECT_UUID}&pageId=${PAGE_ID}" \
  "$OUTFILE"
