#!/usr/bin/env bash
# clear_embedding_cache.sh - Clear the skill-router embedding cache (Bash 版)
# 通常運用は本スクリプトを利用する。PowerShell フォールバック: clear_embedding_cache.ps1
#
# Usage: bash clear_embedding_cache.sh [-Base <base>] | <base>
#
# Removes only vectors.npz and manifest.json. models/ は保持。Exit 0 always.

base=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -Base|--base) base="${2:-}"; shift 2 ;;
    *) [[ -z "$base" ]] && base="$1"; shift ;;
  esac
done

if [[ -z "$base" ]]; then
  # メッセージは PowerShell 版と完全一致 (動作差異ゼロ保証のため拡張子も同じ表記)
  echo 'skill-router: <base> argument required for clear_embedding_cache.ps1'
  exit 0
fi

cache_dir="$base/embeddings_cache"
for file in vectors.npz manifest.json; do
  path="$cache_dir/$file"
  if [[ -f "$path" ]]; then
    rm -f -- "$path" 2>/dev/null || true
  fi
done

echo "skill-router: embedding cache cleared at $cache_dir/"
echo "次回 SessionStart で再生成されます (embedding.enabled=true 時のみ)。"

exit 0
