#!/usr/bin/env bash
# sync-common.sh - sync-settings スキル pull / push スクリプト共通ライブラリ (Bash 純粋実装)
#
#
# 提供する SSOT:
#   - 認証情報除外リスト (EXCLUDE_TARGETS / EXCLUDE_PATTERNS / ENV_FILE_REGEX)
#   - 入力バリデーション正規表現 (REPO_URL_REGEX / BRANCH_REGEX / BRANCH_PREFIX_REGEX)
#   - git CLI 安全オプション (GIT_SAFE_OPTS)
#   - 認証情報二次マスク (SECRET_PATTERNS / hide_secrets / write_masked_output)
#   - 再解析ポイント検査 (test_reparse_item)
#   - 除外判定 (test_target_excluded / test_file_excluded)
#   - 再帰列挙 (get_non_reparse_file_items)
#   - 引数バリデーション (test_repo_url_safe / test_branch_name_safe / test_branch_prefix_safe)
#   - SSOT 永続化 (update_mapping_last_sync_at)
#
# 呼び出し側で `source` するか `. "$(dirname "$0")/sync-common.sh"` で取り込む。
# 単独実行は想定していない。

# --- 認証情報除外 (pull / push 共通 SSOT) ---
EXCLUDE_TARGETS=(
  'credentials.json' 'credential.json' 'credentials.yml' 'credentials.yaml'
  'secrets.json' 'secret.json' 'secrets.yml' 'secrets.yaml'
  '.env' '.netrc' '.git-credentials' '.npmrc' '.pgpass' '.dockercfg'
  '.local' '.git' 'plugins/cache'
  '.ssh' '.gnupg' '.aws' '.docker' '.kube'
)
EXCLUDE_PATTERNS=(
  '*.pem' '*.key' '*.pfx' '*.p12' '*.jks' '*.keystore'
  '*.crt' '*.cer' '*.der' '*.asc' '*.gpg'
  'id_rsa' 'id_rsa.pub' 'id_dsa' 'id_dsa.pub' 'id_ecdsa' 'id_ecdsa.pub'
  'id_ed25519' 'id_ed25519.pub' 'id_xmss' 'id_xmss.pub'
  'serviceAccountKey.json' 'service-account.json'
  'application_default_credentials.json' 'gcloud-credentials.json'
)
ENV_FILE_REGEX='^\.env($|\.)'

# --- 入力バリデーション正規表現 ---
REPO_URL_REGEX='^(https?|git|ssh)://|^git@[A-Za-z0-9._\-]+:'
BRANCH_REGEX='^[A-Za-z0-9._/\-]+$'
BRANCH_PREFIX_REGEX='^[A-Za-z0-9._\-]+$'

# --- git CLI 安全オプション (CVE-2018-17456 系の対策) ---
GIT_SAFE_OPTS=('-c' 'protocol.file.allow=never' '-c' 'protocol.ext.allow=never')

# --- 認証情報の二次マスク ---
SECRET_PATTERNS=(
  'sk-[A-Za-z0-9]{16,}'
  'ghp_[A-Za-z0-9]{20,}'
  'gho_[A-Za-z0-9]{20,}'
  'ghu_[A-Za-z0-9]{20,}'
  'ghs_[A-Za-z0-9]{20,}'
  'ghr_[A-Za-z0-9]{20,}'
  'xox[bpars]-[A-Za-z0-9\-]{10,}'
  'AKIA[A-Z0-9]{16}'
  'AIza[A-Za-z0-9_\-]{35}'
  'glpat-[A-Za-z0-9_\-]{20,}'
  'Bearer[[:space:]]+[A-Za-z0-9._\-]{16,}'
  'https?://[^@/[:space:]]+:[^@/[:space:]]+@'
)

# hide_secrets: 引数 ($1) を [REDACTED] でマスクして stdout に出力 (末尾改行なし)
hide_secrets() {
  local line="${1:-}"
  if [[ -z "$line" ]]; then
    printf '%s' ""
    return
  fi
  local masked="$line"
  local pat
  for pat in "${SECRET_PATTERNS[@]}"; do
    masked="$(printf '%s' "$masked" | sed -E "s|${pat}|[REDACTED]|g")"
  done
  printf '%s' "$masked"
}

# write_masked_output: "  <line>" 形式でマスク済みの行を出力 (末尾改行あり)
write_masked_output() {
  local line="${1:-}"
  printf '  %s\n' "$(hide_secrets "$line")"
}

# --- 再解析ポイント検査 (symlink / junction / mountpoint / 他 reparse tag を拒否) ---
test_reparse_item() {
  local path="${1:-}"
  [[ -z "$path" ]] && return 1
  [[ ! -e "$path" && ! -L "$path" ]] && return 1

  # POSIX symbolic link
  [[ -L "$path" ]] && return 0

  # Windows reparse point (junction / mountpoint / その他 reparse tag)
  if command -v cygpath >/dev/null 2>&1 && command -v fsutil >/dev/null 2>&1; then
    local wpath
    wpath="$(cygpath -w -- "$path" 2>/dev/null)" || return 1
    if [[ -n "$wpath" ]] && fsutil reparsepoint query "$wpath" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

# --- 除外判定 (target レベル) ---
test_target_excluded() {
  local target="${1:-}"
  [[ -z "$target" ]] && return 0
  # NUL バイト混入チェック (bash 変数は NUL を保持しない仕様だが、tr 後の差分で確認)
  if [[ "${target//$'\0'/}" != "$target" ]]; then return 0; fi

  local norm="${target//\\//}"
  [[ "$norm" == ./* ]] && norm="${norm:2}"
  while [[ "$norm" == /* ]]; do norm="${norm:1}"; done
  norm="$(printf '%s' "$norm" | tr '[:upper:]' '[:lower:]')"

  if [[ "$norm" =~ (^|/)\.\.(/|$) ]]; then return 0; fi
  if [[ "$norm" =~ ^[a-z]:/ ]]; then return 0; fi
  case "$target" in /*) return 0 ;; esac

  local ex exnorm
  for ex in "${EXCLUDE_TARGETS[@]}"; do
    exnorm="$(printf '%s' "$ex" | tr '[:upper:]' '[:lower:]')"
    if [[ "$norm" == "$exnorm" || "$norm" == "$exnorm"/* ]]; then
      return 0
    fi
  done

  local leaf="${norm##*/}"
  if [[ "$leaf" =~ $ENV_FILE_REGEX ]]; then return 0; fi
  local pat patnorm
  for pat in "${EXCLUDE_PATTERNS[@]}"; do
    patnorm="$(printf '%s' "$pat" | tr '[:upper:]' '[:lower:]')"
    # shellcheck disable=SC2053
    if [[ "$leaf" == $patnorm ]]; then
      return 0
    fi
  done
  return 1
}

# --- 除外判定 (ファイルレベル) ---
test_file_excluded() {
  local rel="${1:-}"
  [[ -z "$rel" ]] && return 0
  if [[ "${rel//$'\0'/}" != "$rel" ]]; then return 0; fi

  local norm="${rel//\\//}"
  [[ "$norm" == ./* ]] && norm="${norm:2}"
  while [[ "$norm" == /* ]]; do norm="${norm:1}"; done
  norm="$(printf '%s' "$norm" | tr '[:upper:]' '[:lower:]')"

  if [[ "$norm" =~ (^|/)\.\.(/|$) ]]; then return 0; fi

  local ex exnorm
  for ex in "${EXCLUDE_TARGETS[@]}"; do
    exnorm="$(printf '%s' "$ex" | tr '[:upper:]' '[:lower:]')"
    if [[ "$norm" == "$exnorm" || "$norm" == "$exnorm"/* ]]; then
      return 0
    fi
  done

  local leaf="${norm##*/}"
  if [[ "$leaf" =~ $ENV_FILE_REGEX ]]; then return 0; fi
  local pat patnorm
  for pat in "${EXCLUDE_PATTERNS[@]}"; do
    patnorm="$(printf '%s' "$pat" | tr '[:upper:]' '[:lower:]')"
    # shellcheck disable=SC2053
    if [[ "$leaf" == $patnorm ]]; then
      return 0
    fi
  done
  return 1
}

# --- 再帰列挙 (reparse 追従抑制版 find) ---
# 結果は NUL 区切りで stdout に列挙する。最大深さ 32 階層。
get_non_reparse_file_items() {
  local root="${1:?root required}"
  local max_depth="${2:-32}"

  [[ ! -d "$root" ]] && return 0
  if test_reparse_item "$root"; then return 0; fi

  local -a stack=()
  stack+=("$root"$'\t'"0")
  while [[ ${#stack[@]} -gt 0 ]]; do
    local entry="${stack[-1]}"
    unset 'stack[-1]'
    local path="${entry%$'\t'*}"
    local depth="${entry##*$'\t'}"
    (( depth >= max_depth )) && continue

    local child
    while IFS= read -r -d '' child; do
      if test_reparse_item "$child"; then continue; fi
      if [[ -d "$child" ]]; then
        stack+=("$child"$'\t'"$((depth + 1))")
      elif [[ -f "$child" ]]; then
        printf '%s\0' "$child"
      fi
    done < <(find "$path" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  done
}

# --- 安全な引数文字列検証 ---
test_branch_name_safe() {
  local branch="${1:-}"
  [[ -z "$branch" ]] && return 1
  [[ ! "$branch" =~ $BRANCH_REGEX ]] && return 1
  [[ "$branch" == -* ]] && return 1
  [[ "$branch" == /* || "$branch" == */ ]] && return 1
  if [[ "$branch" =~ (^|/)\.\.(/|$) ]]; then return 1; fi
  return 0
}

test_repo_url_safe() {
  local repo="${1:-}"
  [[ -z "$repo" ]] && return 1
  [[ ! "$repo" =~ $REPO_URL_REGEX ]] && return 1
  [[ "$repo" == -* ]] && return 1
  if [[ "${repo//$'\0'/}" != "$repo" ]]; then return 1; fi
  return 0
}

test_branch_prefix_safe() {
  local prefix="${1:-}"
  [[ -z "$prefix" ]] && return 1
  [[ ! "$prefix" =~ $BRANCH_PREFIX_REGEX ]] && return 1
  [[ "$prefix" == -* ]] && return 1
  return 0
}

# --- SSOT 永続化: sync-mappings.json の該当マッピングの last_sync_at を更新 ---
# 引数: <scope: global|project|""> <project_path> <mappings_file> <iso8601>
update_mapping_last_sync_at() {
  local scope="${1:-}"
  local project_path="${2:-}"
  local mappings_file="${3:-}"
  local iso="${4:-}"
  [[ -z "$scope" ]] && return 0
  [[ ! -f "$mappings_file" ]] && return 0
  if ! command -v jq >/dev/null 2>&1; then
    printf '[update-mapping] jq が見つからないため last_sync_at 更新をスキップ\n' >&2
    return 0
  fi

  local store
  if ! store="$(jq -e . "$mappings_file" 2>/dev/null)"; then
    printf '[update-mapping] sync-mappings.json のパース失敗（last_sync_at 更新をスキップ）\n' >&2
    return 0
  fi

  local updated
  if [[ "$scope" == "global" ]]; then
    if [[ "$(printf '%s' "$store" | jq 'has("global") and (.global != null)')" != "true" ]]; then
      return 0
    fi
    updated="$(printf '%s' "$store" | jq --arg v "$iso" '.global.last_sync_at = $v')"
  elif [[ "$scope" == "project" ]]; then
    local resolved="$project_path"
    if [[ -z "$resolved" ]]; then
      local tmp
      if tmp="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$tmp" ]]; then
        resolved="$tmp"
      else
        resolved="$(pwd)"
      fi
    fi
    # sync-mappings.json では Windows 形式 (バックスラッシュ) で格納されるため変換
    if [[ -e "$resolved" ]] && command -v cygpath >/dev/null 2>&1; then
      local wpath
      if wpath="$(cygpath -w -- "$resolved" 2>/dev/null)" && [[ -n "$wpath" ]]; then
        resolved="$wpath"
      fi
    fi
    if [[ "$(printf '%s' "$store" | jq --arg k "$resolved" 'has("projects") and (.projects != null) and (.projects | has($k))')" != "true" ]]; then
      return 0
    fi
    updated="$(printf '%s' "$store" | jq --arg k "$resolved" --arg v "$iso" '.projects[$k].last_sync_at = $v')"
  else
    return 0
  fi

  local dir
  dir="$(dirname -- "$mappings_file")"
  mkdir -p -- "$dir" 2>/dev/null || true
  if ! printf '%s\n' "$updated" > "$mappings_file" 2>/dev/null; then
    printf '[update-mapping] sync-mappings.json の保存に失敗しました\n' >&2
  fi
}
