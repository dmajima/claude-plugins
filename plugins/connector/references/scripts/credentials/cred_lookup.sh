#!/usr/bin/env bash
# cred_lookup.sh - 認証情報ストア（credentials.json）の横断照合（connector 共通）
#
# ストアの一覧・順序は references/credentials-precheck.md セクション 2.1 が SSOT。
# 値は stdout にのみ出力する（会話・ログへの転記はマスク必須 — 同セクション 4.3）。
#
# 使い方:
#   bash cred_lookup.sh --list-stores
#     存在するストアのパスを優先順に 1 行ずつ出力する（0 件でも exit 0）
#   bash cred_lookup.sh --domain <host> [--field <field>]
#     全ストアを順に照合し、domains に <host> を含む最初のエントリの <field>（既定: value）を出力する
#   bash cred_lookup.sh --entry <name> [--field <field>]
#     エントリ名 <name> の <field>（既定: value）を最初に見つかったストアから出力する
#     （--field username は auth_method の ntlm:<user> / basic:<user> からの抽出フォールバック付き）
#
# 終了コード:
#   0=取得成功 / 1=未解決（credentials-precheck.md セクション 4（対話取得フォールバック）・
#   サブエージェント実行時は同セクション 5 へ） / 2=引数エラー
#
# 前提: リポジトリ内ストア（優先 1）の解決は現在の作業ディレクトリの .git に依存する。
#   出所不明のリポジトリを開いた状態で認証操作を行わないこと（credentials-precheck.md セクション 7）
set -euo pipefail

usage() {
  echo "usage: cred_lookup.sh --list-stores | --domain <host> [--field <f>] | --entry <name> [--field <f>]" >&2
  exit 2
}

MODE=""; HOST=""; ENTRY=""; FIELD="value"
while [ $# -gt 0 ]; do
  case "$1" in
    --list-stores) MODE="list"; shift ;;
    --domain) MODE="domain"; HOST="${2:?--domain には値が必要}"; shift 2 ;;
    --entry) MODE="entry"; ENTRY="${2:?--entry には値が必要}"; shift 2 ;;
    --field) FIELD="${2:?--field には値が必要}"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$MODE" ] || usage
[[ "$FIELD" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "field が不正（英数字と _ のみ）" >&2; exit 2; }
if [ "$MODE" = "domain" ]; then
  [[ "$HOST" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "host が不正（英数字と . - のみ）" >&2; exit 2; }
fi
if [ "$MODE" = "entry" ]; then
  [[ "$ENTRY" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "entry-name が不正（^[A-Za-z0-9._-]+\$）" >&2; exit 2; }
fi

# ストア列挙（credentials-precheck.md セクション 2.1 の順序）
list_stores() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$repo_root" ] && [ -f "$repo_root/.claude/.local/plugins/credentials-manager/credentials.json" ]; then
    printf '%s\n' "$repo_root/.claude/.local/plugins/credentials-manager/credentials.json"
  fi
  # チルダ表記を使用（path-portability.md 準拠。bash のチルダ展開は単語分割されないため空白入りホームでも安全）
  if [ -f ~/.claude/.local/plugins/credentials-manager/credentials.json ]; then
    printf '%s\n' ~/.claude/.local/plugins/credentials-manager/credentials.json
  fi
  if [ -f ~/.claude/credentials.json ]; then
    printf '%s\n' ~/.claude/credentials.json
  fi
  return 0
}

if [ "$MODE" = "list" ]; then
  list_stores
  exit 0
fi

FOUND=""
while IFS= read -r store; do
  [ -n "$store" ] || continue
  case "$MODE" in
    domain)
      v=$(jq -r --arg host "$HOST" --arg f "$FIELD" \
        '.credentials | to_entries[] | select(.value.domains[]? == $host) | .value[$f] // empty' \
        "$store" 2>/dev/null | head -n 1 || true)
      ;;
    entry)
      v=$(jq -r --arg name "$ENTRY" --arg f "$FIELD" '.credentials[$name][$f] // empty' "$store" 2>/dev/null || true)
      if [ -z "$v" ] && [ "$FIELD" = "username" ]; then
        auth=$(jq -r --arg name "$ENTRY" '.credentials[$name].auth_method // empty' "$store" 2>/dev/null || true)
        case "$auth" in (ntlm:*|basic:*) v="${auth#*:}" ;; esac
      fi
      ;;
  esac
  if [ -n "${v:-}" ]; then FOUND="$v"; break; fi
done < <(list_stores)

[ -n "$FOUND" ] || exit 1
printf '%s\n' "$FOUND"
