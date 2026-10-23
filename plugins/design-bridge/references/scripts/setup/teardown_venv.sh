#!/usr/bin/env bash
# design-bridge プラグイン venv 削除スクリプト
#
# setup_venv.sh が構築した venv
# （<project>/.claude/.local/plugins/design-bridge/.venv）を削除する。
#
# この venv はプロジェクト単位で永続利用する前提のため、通常のタスク完了時には
# 削除しない。ディスクを空けたい場合や、依存を入れ直したい場合にのみ使う。
#
# 使い方:
#   bash teardown_venv.sh
#   bash teardown_venv.sh --project-root <path>
#
# 終了コード: 0 = 成功（存在しない場合を含む） / 2 = 引数エラー

set -uo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../hooks/lib/design_bridge_common.sh
source "${script_dir}/../hooks/lib/design_bridge_common.sh" 2>/dev/null || {
  echo "共通ライブラリを読み込めません" >&2
  exit 2
}

project_root=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      # 値なしで渡されたときに shift 2 が失敗すると、$1 が変わらないまま
      # ループが回り続けて出力ゼロのまま固まる。先にガードする。
      if [[ -z "${2:-}" ]]; then
        echo "エラー: --project-root に値が必要です" >&2
        exit 2
      fi
      project_root="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" >&2; exit 0 ;;
    *)
      echo "不明なオプション: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$project_root" ]]; then
  project_root="$(db_find_project_root "$PWD")"
fi
if [[ -z "$project_root" ]]; then
  echo "プロジェクトルート（.git のあるディレクトリ）を特定できません。--project-root で指定してください" >&2
  exit 2
fi
project_root="$(db_normalize_path "$project_root")"

venv_path="$(db_state_dir "$project_root")/.venv"

if [[ -d "$venv_path" ]]; then
  rm -rf -- "$venv_path"
  echo "[DONE] venv を削除しました: $venv_path"
else
  echo "[OK] venv は存在しません: $venv_path"
fi
