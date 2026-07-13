#!/usr/bin/env bash
# cred_save.sh - 対話取得フォールバック「保存する」の保存処理（connector 共通）
#
# 保存先の決定ルール・セキュリティ制約は references/credentials-precheck.md セクション 4.5 が SSOT。
# ユーザーが AskUserQuestion で「入力して続行（保存する）」を明示選択した場合にのみ呼び出すこと。
#
# 使い方:
#   bash cred_save.sh <entry-name> <entry-file>
#     <entry-name>: 保存するエントリ名（^[A-Za-z0-9._-]+$ のみ許可）
#     <entry-file>: credentials-precheck.md セクション 3 の標準スキーマの JSON オブジェクト
#                   （1 エントリ分の値）。Write ツール等で作成しておく。処理後に必ず削除される
#
# 出力: 保存先ストアのパスのみ（認証情報の値は出力しない）
# 終了コード: 0=保存成功 / 1=保存失敗（既存ストアは変更されない。リポジトリ内ストアが
#   .gitignore 未登録の場合も 1 で中止） / 2=引数エラー
#
# セキュリティガード:
#   - リポジトリ内ストアへの書き込みは「同名エントリの更新」かつ「.gitignore 対象」の場合のみ。
#     新規エントリは常にホーム側ストアへ保存する（悪意あるリポジトリによる保存先誘導の防止）
#   - Windows（Git Bash）では chmod 600 は NTFS ACL に作用しない。ストアの機密性は
#     ユーザープロファイル配下の既定 ACL に依存する（credentials-manager の運用と同一）
set -euo pipefail

ENTRY_NAME="${1:?usage: cred_save.sh <entry-name> <entry-file>}"
ENTRY_FILE="${2:?usage: cred_save.sh <entry-name> <entry-file>}"

TMP=""
cleanup() { rm -f "${TMP:-}" "${ENTRY_FILE:-}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM HUP QUIT

[[ "$ENTRY_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "entry-name が不正（^[A-Za-z0-9._-]+\$ のみ許可）" >&2; exit 2; }
[ -f "$ENTRY_FILE" ] || { echo "entry-file が存在しない: $ENTRY_FILE" >&2; exit 2; }
chmod 600 "$ENTRY_FILE"
jq -e 'type == "object"' "$ENTRY_FILE" >/dev/null 2>&1 || { echo "entry-file が JSON オブジェクトとして不正" >&2; exit 2; }

# ストア列挙（credentials-precheck.md セクション 2.1。cred_lookup.sh に委譲）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mapfile -t STORES < <(bash "$SCRIPT_DIR/cred_lookup.sh" --list-stores)

# リポジトリ内ストアのパス（保存先誘導ガードの判定に使用）
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
REPO_STORE=""
[ -n "$REPO_ROOT" ] && REPO_STORE="$REPO_ROOT/.claude/.local/plugins/credentials-manager/credentials.json"

# リポジトリ内ストアがシンボリックリンクの場合は拒否する
# （悪意あるリポジトリがホームストア等へのリンクを同梱し、読み書き先をすり替える経路の遮断）
if [ -n "$REPO_STORE" ] && [ -L "$REPO_STORE" ]; then
  echo "中止: リポジトリ内ストアがシンボリックリンクです（すり替えの可能性）: $REPO_STORE" >&2
  exit 1
fi

# 保存先決定（credentials-precheck.md セクション 4.5 の表 + 保存先誘導ガード）
# ガード: リポジトリ内ストアは「同名エントリが既に存在する場合」のみ更新対象とする。
#   domains 交差やストアの存在だけを根拠に、開いているリポジトリ配下へ新規シークレットを
#   書き込まない（悪意あるリポジトリ内ストアによる保存先誘導 → シークレット流出の防止）。
#   新規エントリの保存先は常にホーム側（cm ホームストア → 従来共有パス）に限定する。
TARGET=""
ENTRY_DOMAINS=$(jq -c '.domains // []' "$ENTRY_FILE")
# 1) 既存エントリのあるストアを更新（リポジトリ内ストアは同名一致のみ・ホーム側は同名 or domains 交差）
for s in "${STORES[@]}"; do
  if [ -n "$REPO_STORE" ] && [ "$s" = "$REPO_STORE" ]; then
    jq -e --arg name "$ENTRY_NAME" '.credentials[$name] != null' "$s" >/dev/null 2>&1 \
      && { TARGET="$s"; break; }
  else
    jq -e --arg name "$ENTRY_NAME" --argjson doms "$ENTRY_DOMAINS" \
        '(.credentials[$name] != null) or any(.credentials[].domains[]?; ($doms | index(.)) != null)' \
        "$s" >/dev/null 2>&1 \
      && { TARGET="$s"; break; }
  fi
done
# 2) credentials-manager のホーム側ストア（存在すれば追記。ストア分裂防止）
if [ -z "$TARGET" ] && [ -f ~/.claude/.local/plugins/credentials-manager/credentials.json ]; then
  TARGET=~/.claude/.local/plugins/credentials-manager/credentials.json
fi
# 3) いずれも無ければ従来の共有パスを新規作成（チルダ表記 — path-portability.md 準拠）
[ -n "$TARGET" ] || TARGET=~/.claude/credentials.json

# リポジトリ内ストアへ書き込む場合は .gitignore 対象であることを必須とする（コミット事故防止）
if [ -n "$REPO_STORE" ] && [ "$TARGET" = "$REPO_STORE" ]; then
  if ! git -C "$REPO_ROOT" check-ignore -q -- "$TARGET" 2>/dev/null; then
    echo "中止: リポジトリ内ストアが .gitignore 対象ではない（.claude/.local/ を .gitignore に登録してから再実行）: $TARGET" >&2
    exit 1
  fi
fi

# マージ書き込み（新規・既存とも保存先と同一ディレクトリの一時ファイル + mv。
# 同一ファイルシステム内 rename の原子性を保証し、jq 失敗時は既存ストアを変更しない）
TARGET_DIR=$(dirname "$TARGET")
mkdir -p "$TARGET_DIR"
TMP=$(mktemp "$TARGET_DIR/.cred_save.XXXXXX")
chmod 600 "$TMP"
if [ -f "$TARGET" ]; then
  jq --arg name "$ENTRY_NAME" --slurpfile e "$ENTRY_FILE" '.credentials[$name] = $e[0]' "$TARGET" > "$TMP"
else
  jq -n --arg name "$ENTRY_NAME" --slurpfile e "$ENTRY_FILE" '{credentials: {($name): $e[0]}}' > "$TMP"
fi
mv "$TMP" "$TARGET"
TMP=""
chmod 600 "$TARGET" 2>/dev/null || true
printf '%s\n' "$TARGET"
