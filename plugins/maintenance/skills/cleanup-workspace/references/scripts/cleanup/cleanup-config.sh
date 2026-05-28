#!/usr/bin/env bash
# cleanup-config.sh - cleanup-workspace 閾値設定の表示・変更・リセット (Bash + jq 純粋実装)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: cleanup-config.ps1 (機能等価、歴史的経緯で保持)
#
# 使い方:
#   bash cleanup-config.sh                       # 現在の設定表示
#   bash cleanup-config.sh -SetDays 60           # default_days = 60 に変更
#   bash cleanup-config.sh -SetScope global      # default_scope = global
#   bash cleanup-config.sh -Reset -Yes           # 出荷時デフォルトにリセット

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "[cleanup-config] jq required" >&2; exit 1; }

home_dir="${USERPROFILE:-${HOME:-}}"
config_dir="$home_dir/.claude/.local/plugins/maintenance"
config_file="$config_dir/cleanup-config.json"

# 出荷時デフォルト
default_config='{
  "version": 1,
  "default_days": 30,
  "default_keep_recent": 0,
  "default_scope": "both",
  "active_session_minutes": 5,
  "atime_strategy": "progress_md"
}'

# 引数解析
show=0
set_days=""
set_keep_recent=""
set_scope=""
set_active_minutes=""
reset=0
yes=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Show|--show)                           show=1; shift ;;
    -SetDays|--set-days)                    set_days="${2:-}"; shift 2 ;;
    -SetKeepRecent|--set-keep-recent)       set_keep_recent="${2:-}"; shift 2 ;;
    -SetScope|--set-scope)                  set_scope="${2:-}"; shift 2 ;;
    -SetActiveSessionMinutes|--set-active-session-minutes)
                                            set_active_minutes="${2:-}"; shift 2 ;;
    -Reset|--reset)                         reset=1; shift ;;
    -Yes|--yes)                             yes=1; shift ;;
    *) shift ;;
  esac
done

# scope の値検証
if [[ -n "$set_scope" ]]; then
  case "$set_scope" in
    global|project|both) ;;
    *) echo "--SetScope は global / project / both のいずれかを指定してください。" >&2; exit 1 ;;
  esac
fi

# 設定読込
get_config() {
  if [[ ! -f "$config_file" ]]; then
    printf '%s' "$default_config"
    return
  fi
  local loaded
  if ! loaded="$(jq -e . "$config_file" 2>/dev/null)"; then
    echo "[cleanup-config] cleanup-config.json のパース失敗" >&2
    echo "[cleanup-config] 出荷時デフォルトを返します。修正後に再保存してください。" >&2
    printf '%s' "$default_config"
    return
  fi
  # スキーマバージョン検証
  local loaded_version default_version
  loaded_version="$(printf '%s' "$loaded" | jq -r '.version // empty')"
  default_version="$(printf '%s' "$default_config" | jq -r '.version')"
  if [[ -n "$loaded_version" && "$loaded_version" != "$default_version" ]]; then
    echo "[schema] cleanup-config.json の version=$loaded_version は本スキーマ (version=$default_version) と一致しません。出荷時デフォルトを採用します。" >&2
    printf '%s' "$default_config"
    return
  fi
  # 既定値で不足フィールド補完 (default に loaded を merge)
  printf '%s' "$default_config" | jq --argjson l "$loaded" '. * $l'
}

save_config() {
  local cfg="$1"
  if ! mkdir -p -- "$config_dir" 2>/dev/null; then
    echo "[cleanup-config] cleanup-config.json の保存に失敗しました: ディレクトリ作成失敗" >&2
    exit 1
  fi
  if ! printf '%s\n' "$cfg" | jq . > "$config_file" 2>/dev/null; then
    echo "[cleanup-config] cleanup-config.json の保存に失敗しました" >&2
    exit 1
  fi
}

format_config() {
  local cfg="$1"
  local exists
  if [[ -f "$config_file" ]]; then exists="True"; else exists="False"; fi
  echo "===== cleanup-workspace 閾値設定 ====="
  echo "Config file: $config_file"
  echo "Exists:      $exists"
  echo ""
  echo "version:                 $(printf '%s' "$cfg" | jq -r '.version')"
  echo "default_days:            $(printf '%s' "$cfg" | jq -r '.default_days') 日"
  echo "default_keep_recent:     $(printf '%s' "$cfg" | jq -r '.default_keep_recent') 件"
  echo "default_scope:           $(printf '%s' "$cfg" | jq -r '.default_scope')"
  echo "active_session_minutes:  $(printf '%s' "$cfg" | jq -r '.active_session_minutes') 分"
  echo "atime_strategy:          $(printf '%s' "$cfg" | jq -r '.atime_strategy')"
}

config="$(get_config)"
modified=0

# Reset 処理
if [[ "$reset" -eq 1 ]]; then
  if [[ "$yes" -ne 1 ]]; then
    echo "--Reset は破壊的です。--Yes フラグを併用してください。" >&2
    exit 1
  fi
  save_config "$default_config"
  echo "===== cleanup-config.json を出荷時デフォルトにリセットしました ====="
  format_config "$default_config"
  exit 0
fi

# 各 -Set* オプションの適用
if [[ -n "$set_days" ]]; then
  if ! [[ "$set_days" =~ ^[0-9]+$ ]]; then
    echo "--SetDays は 0 以上の整数を指定してください。" >&2
    exit 1
  fi
  config="$(printf '%s' "$config" | jq --argjson v "$set_days" '.default_days = $v')"
  modified=1
  echo "[updated] default_days = $set_days"
fi

if [[ -n "$set_keep_recent" ]]; then
  if ! [[ "$set_keep_recent" =~ ^[0-9]+$ ]]; then
    echo "--SetKeepRecent は 0 以上の整数を指定してください。" >&2
    exit 1
  fi
  config="$(printf '%s' "$config" | jq --argjson v "$set_keep_recent" '.default_keep_recent = $v')"
  modified=1
  echo "[updated] default_keep_recent = $set_keep_recent"
fi

if [[ -n "$set_scope" ]]; then
  config="$(printf '%s' "$config" | jq --arg v "$set_scope" '.default_scope = $v')"
  modified=1
  echo "[updated] default_scope = $set_scope"
fi

if [[ -n "$set_active_minutes" ]]; then
  if ! [[ "$set_active_minutes" =~ ^[1-9][0-9]*$ ]]; then
    echo "--SetActiveSessionMinutes は 1 以上の整数を指定してください。" >&2
    exit 1
  fi
  config="$(printf '%s' "$config" | jq --argjson v "$set_active_minutes" '.active_session_minutes = $v')"
  modified=1
  echo "[updated] active_session_minutes = $set_active_minutes"
fi

# 保存
if [[ "$modified" -eq 1 ]]; then
  save_config "$config"
  echo ""
  format_config "$config"
  exit 0
fi

# 引数なし or --Show: 現在の設定表示のみ
format_config "$config"
exit 0
