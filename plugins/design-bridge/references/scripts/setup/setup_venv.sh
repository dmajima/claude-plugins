#!/usr/bin/env bash
# design-bridge プラグイン venv 構築スクリプト
#
# スクリーンショット生成（Playwright）用の venv を構築する。
#
# venv はセッション作業領域ではなく、プロジェクトのローカルデータ領域
# （.claude/.local/plugins/design-bridge/.venv）へ永続構築する。Playwright の
# Chromium バイナリは展開後 約 690 MB あり、セッションごとに作り直すのは現実的でない
# ため、本プラグインが自前でライフサイクルを管理する（teardown_venv.sh で
# 明示的に削除できる）。
#
# 使い方:
#   bash setup_venv.sh                         # 現在地からプロジェクトルートを探索
#   bash setup_venv.sh --project-root <path>
#   bash setup_venv.sh --project-root <path> --skip-browser
#
# 終了コード: 0 = 成功 / 1 = 構築失敗 / 2 = 引数エラー

set -uo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../hooks/lib/design_bridge_common.sh
source "${script_dir}/../hooks/lib/design_bridge_common.sh" 2>/dev/null || {
  echo "共通ライブラリを読み込めません" >&2
  exit 2
}

project_root=""
skip_browser=false

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
    --skip-browser)
      skip_browser=true; shift ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" >&2; exit 0 ;;
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

base_dir="$(db_state_dir "$project_root")"
venv_path="$base_dir/.venv"
requirements_path="$script_dir/requirements.txt"

mkdir -p -- "$base_dir" || {
  echo "ディレクトリを作成できません: $base_dir" >&2
  exit 1
}

if [[ ! -d "$venv_path" ]]; then
  echo "[OK] venv を作成します: $venv_path"
  if ! python -m venv "$venv_path"; then
    echo "venv の作成に失敗しました: $venv_path" >&2
    exit 1
  fi
else
  echo "[OK] 既存の venv を再利用します: $venv_path"
fi

python_exe=""
if [[ -f "$venv_path/Scripts/python.exe" ]]; then
  python_exe="$venv_path/Scripts/python.exe"
elif [[ -f "$venv_path/bin/python" ]]; then
  python_exe="$venv_path/bin/python"
else
  echo "venv の python が見つかりません: $venv_path" >&2
  exit 1
fi

if [[ -f "$requirements_path" ]]; then
  echo "[OK] 依存パッケージを導入します: $requirements_path"
  "$python_exe" -m pip install --quiet --upgrade pip >/dev/null 2>&1
  if ! "$python_exe" -m pip install --quiet -r "$requirements_path"; then
    echo "pip install に失敗しました" >&2
    exit 1
  fi
else
  echo "[WARN] requirements.txt が見つかりません: $requirements_path" >&2
fi

if [[ "$skip_browser" == false ]]; then
  echo "[OK] Chromium を導入します（初回はダウンロードが発生し、展開後 約 690 MB を使用します）"
  if ! "$python_exe" -m playwright install chromium; then
    echo "[WARN] Chromium の導入に失敗しました。スクリーンショット生成は動作しません。" >&2
    echo "       後から次を実行してください: \"$python_exe\" -m playwright install chromium" >&2
    exit 1
  fi
fi

echo "[DONE] venv 準備完了: $venv_path"
echo "       python: $python_exe"
