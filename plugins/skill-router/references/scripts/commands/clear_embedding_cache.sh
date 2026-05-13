#!/usr/bin/env bash
# Clear the skill-router embedding cache files (vectors + manifest).
#
# Usage:
#   clear_embedding_cache.sh <base>
#
# Removes only vectors.npz and manifest.json. The models/ subdirectory is
# preserved so that the next SessionStart does not re-download the ONNX model
# (potentially a 120MB transfer).
#
# Exit 0 always (fail-open).

set -uo pipefail

BASE="${1:-}"
if [[ -z "${BASE}" ]]; then
    echo "skill-router: <base> argument required for clear_embedding_cache.sh"
    exit 0
fi

CACHE_DIR="${BASE}/embeddings_cache"
rm -f "${CACHE_DIR}/vectors.npz" "${CACHE_DIR}/manifest.json"

echo "skill-router: embedding cache cleared at ${CACHE_DIR}/"
echo "次回 SessionStart で再生成されます（embedding.enabled=true 時のみ）。"

exit 0
