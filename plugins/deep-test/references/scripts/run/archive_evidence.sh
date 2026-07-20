#!/usr/bin/env bash
# エビデンス外部共有用アーカイブスクリプト（deep-test 共通）
#
# 目的:
# - 報告書を外部ステークホルダーへ共有する際に、テスト実績データディレクトリの
#   evidence/ 一式（および任意で報告書ファイル）を 1 つのアーカイブにまとめる。
# - data-locations.md 7.2（evidence の手動クリーンアップ）で、古い run の evidence を
#   アーカイブしてから削除する用途にも使う（--run で対象 run を限定）。
#
# 報告書（Excel / Markdown）はセッション作業領域に出力され、evidence/ とは別ツリーに
# あるため（data-locations.md 6 章）、外部共有時は報告書を追加引数で明示的に含める。
#
# usage:
#   archive_evidence.sh [--run <run_id>] <target-dir> <output-archive> [report-file...]
#
#   <target-dir>      : テスト対象のデータディレクトリ（{base}/{target-slug}。evidence/ を含む）
#   <output-archive>  : 出力アーカイブパス（.zip は zip、それ以外は tar.gz。既定 tar.gz）
#   [report-file...]  : 同梱する報告書等のファイル（0 個以上・任意）
#   --run <run_id>    : evidence/<run_id> のみをアーカイブ対象にする（省略時は evidence/ 全体）
#
# 例:
#   # 報告書 + 全 evidence を外部共有用にまとめる
#   archive_evidence.sh "$BASE/orderapp-web" share/orderapp-evidence.tar.gz \
#       "$SESSION/test-report_orderapp-web_20260717.md"
#   # 古い run の evidence だけをアーカイブ（クリーンアップ前のバックアップ）
#   archive_evidence.sh --run R20260601-090000 "$BASE/orderapp-web" \
#       "$BASE/orderapp-web/archive/evidence-R20260601-090000.tar.gz"
#
# exit code: 0=成功 / 64=引数エラー / 66=入力パス不在 / 69=必要コマンド不在
set -euo pipefail

run_id=""
positional=()

# --- 引数パース（--run オプションと位置引数を分離）---
while [ $# -gt 0 ]; do
    case "$1" in
        --run)   run_id="${2:-}"; shift 2 ;;
        --run=*) run_id="${1#--run=}"; shift ;;
        --)      shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
        -*)      echo "[archive_evidence] 不明なオプション: $1" >&2; exit 64 ;;
        *)       positional+=("$1"); shift ;;
    esac
done

if [ "${#positional[@]}" -lt 2 ]; then
    echo "usage: archive_evidence.sh [--run <run_id>] <target-dir> <output-archive> [report-file...]" >&2
    exit 64
fi

target_dir="${positional[0]}"
output_archive="${positional[1]}"
reports=("${positional[@]:2}")

# --- 入力検証 ---
if [ ! -d "$target_dir" ]; then
    echo "[archive_evidence] target ディレクトリが存在しません: $target_dir" >&2
    exit 66
fi

# アーカイブ対象の evidence 相対パス（--run 指定時は当該 run のみ）
if [ -n "$run_id" ]; then
    evidence_rel="evidence/$run_id"
else
    evidence_rel="evidence"
fi
if [ ! -d "$target_dir/$evidence_rel" ]; then
    echo "[archive_evidence] エビデンスディレクトリが存在しません: $target_dir/$evidence_rel" >&2
    exit 66
fi

# 報告書ファイルの実在検証（存在しないパスの同梱を防ぐ）
for r in ${reports[@]+"${reports[@]}"}; do
    if [ ! -f "$r" ]; then
        echo "[archive_evidence] 報告書ファイルが存在しません: $r" >&2
        exit 66
    fi
done

# 出力先の親ディレクトリを作成する
out_parent="$(dirname -- "$output_archive")"
mkdir -p -- "$out_parent"

# target を相対パスで格納するため、親ディレクトリと名前を分離する（絶対パス格納を避ける）
target_parent="$(cd "$(dirname -- "$target_dir")" && pwd)"
target_name="$(basename -- "$target_dir")"

# --- アーカイブ形式の判定（拡張子ベース。既定 tar.gz）---
case "$output_archive" in
    *.zip) fmt="zip" ;;
    *)     fmt="tar" ;;
esac

if [ "$fmt" = "zip" ]; then
    if ! command -v zip >/dev/null 2>&1; then
        echo "[archive_evidence] zip コマンドが見つかりません。出力先を .tar.gz にするか zip を導入してください。" >&2
        exit 69
    fi
    output_abs="$(cd "$out_parent" && pwd)/$(basename -- "$output_archive")"
    rm -f -- "$output_abs"
    # evidence: target の親から相対パスで格納 / 報告書: パスを除いて（-j）アーカイブ直下へ
    ( cd "$target_parent" && zip -r -q "$output_abs" "$target_name/$evidence_rel" )
    for r in ${reports[@]+"${reports[@]}"}; do
        zip -j -q "$output_abs" "$r"
    done
    echo "[archive_evidence] zip アーカイブを作成しました: $output_archive"
    zip -sf "$output_abs" | head || true
else
    # tar.gz: -C で格納ルートを切り替え、evidence と各報告書を相対パスで格納する。
    # 出力パスにドライブレター（例: C:）のコロンが含まれると GNU tar がリモートホスト
    # 指定と誤認するため、出力親ディレクトリへ移動してコロンなしのアーカイブ名で作成する。
    archive_name="$(basename -- "$output_archive")"
    out_abs_parent="$(cd "$out_parent" && pwd)"
    tar_args=(-czf "$archive_name" -C "$target_parent" "$target_name/$evidence_rel")
    for r in ${reports[@]+"${reports[@]}"}; do
        r_parent="$(cd "$(dirname -- "$r")" && pwd)"
        r_name="$(basename -- "$r")"
        tar_args+=(-C "$r_parent" "$r_name")
    done
    ( cd "$out_abs_parent" && tar "${tar_args[@]}" )
    echo "[archive_evidence] tar.gz アーカイブを作成しました: $output_archive"
    ( cd "$out_abs_parent" && tar -tzf "$archive_name" | head ) || true
fi

echo "[archive_evidence] 完了: $output_archive"
