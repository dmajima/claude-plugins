#!/usr/bin/env bash
# cleanup_sensitive.sh - projectboard スキルの機密ファイル後始末スクリプト
#
# 使い方:
#   bash "${CLAUDE_SKILL_DIR}/references/scripts/cleanup/cleanup_sensitive.sh" <WORK_DIR>
#
# 引数:
#   WORK_DIR  セッション作業領域（cookies.txt 等が生成されたディレクトリ）
#
# 削除対象（すべて $WORK_DIR 配下のみ。それ以外の場所は触らない）:
#   - cookies.txt            セッション Cookie（SESSION / XSRF-TOKEN を含む）
#   - pb_*.json              ProjectBoard API の取得レスポンス（個人名・内部情報を含み得る）
#   - pb_*.csv               整形済みタスク CSV
#   - *.har                  ブラウザキャプチャ（Cookie・トークンを含む）
#
# 注意: タスク CSV / 解析結果を成果物として残す場合は、削除前にセッションフォルダ
#       直下（成果物置き場）へ移動しておくこと。本スクリプトは workspace 内の
#       中間生成物を機密ごと消すための最終手段。
#       pb_*.md（解析レポート）は成果物として意図的に削除対象外。個人名・組織内部
#       スケジュールを含むため、成果物の移動先・共有範囲の管理に注意すること。

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください}"

if [ ! -d "$WORK_DIR" ]; then
  echo "エラー: WORK_DIR が存在しません: $WORK_DIR" >&2
  exit 1
fi

deleted=0
for f in "$WORK_DIR/cookies.txt" "$WORK_DIR"/pb_*.json "$WORK_DIR"/pb_*.csv "$WORK_DIR"/*.har; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "削除: $f"
    deleted=$((deleted + 1))
  fi
done

echo "機密ファイル後始末完了: ${deleted} 件削除"
