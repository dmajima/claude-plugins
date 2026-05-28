#!/usr/bin/env bash
# tests/parity/lib/capture.sh
# 任意コマンドの stdout / stderr / exit code をファイルに分離してキャプチャする。
#
# 使い方:
#   parity_capture <out_dir> <stdin_file_or_empty> <env_vars_array_name> <workdir> <cmd...>
#
# 出力ファイル:
#   <out_dir>/stdout
#   <out_dir>/stderr
#   <out_dir>/exit

parity_capture() {
  local out_dir="$1"; shift
  local stdin_file="$1"; shift
  local env_arr_name="$1"; shift
  local workdir="$1"; shift
  # 残りの引数 = 実行コマンド

  mkdir -p "$out_dir"
  local out="$out_dir/stdout"
  local err="$out_dir/stderr"
  local code_file="$out_dir/exit"

  # 環境変数配列を取得（呼び出し元で定義された配列）
  local -a env_pairs=()
  if [[ -n "$env_arr_name" ]]; then
    eval "env_pairs=(\"\${${env_arr_name}[@]+\"\${${env_arr_name}[@]}\"}\")"
  fi

  # サブシェルで実行（cd や env が呼び出し側に影響しないように）
  (
    set +e
    if [[ -n "$workdir" ]]; then
      cd "$workdir" || exit 127
    fi
    if [[ -n "$stdin_file" && -f "$stdin_file" ]]; then
      env "${env_pairs[@]}" "$@" >"$out" 2>"$err" <"$stdin_file"
    else
      env "${env_pairs[@]}" "$@" >"$out" 2>"$err" </dev/null
    fi
    printf '%d' "$?" >"$code_file"
  )
}
