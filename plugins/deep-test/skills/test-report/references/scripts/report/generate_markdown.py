#!/usr/bin/env python3
"""deep-test / test-report: Markdown 報告書生成スクリプト。

test-results.yaml / test-cases.yaml を読み込み、テスト報告書（.md 1 ファイル）を生成する。

- フォーマット SSOT: プラグイン共通 references/report-format.md 4 章
  （1 ファイル 6 章: サマリ → 推移 → レベル別 → NG 詳細 → 未確認事項 → 免責注記）
- 表は GFM。列構成はレベル別セクションで Excel（report-format.md 3.4）と揃える
- 読み込み・集計・共通定数は同ディレクトリの report_model.py に一元化
  （generate_excel.py と共有。集計規則: latest 採用 / deprecated 除外）
- エビデンス参照は Excel と対称なコード span のパス文字列表記（リンク構文は使わない）。
  パスの基準（テスト実績データディレクトリ）はサマリ章に注記として必ず出力する
- セクション記号（U+00A7）を出力しない（入力に含まれる場合は代替表現へ置換して警告）
- 集計はすべて本スクリプトの機械集計であり、LLM の手計算を介在させない

使い方:
    python generate_markdown.py --results <test-results.yaml> --cases <test-cases.yaml> \
        --output <出力 .md パス>
"""

import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

import argparse
import os
from datetime import date

# 同ディレクトリの共通データモデルモジュール（report_model.py）を import する
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from report_model import (
    LEVEL_TERM_NOTES,
    VERDICT_DESCRIPTIONS,
    add_sanitized,
    annotation_target,
    build_disclaimer_rows,
    build_model,
    date_part,
    evidence_path_note,
    format_duration,
    join_lines,
    level_label,
    load_yaml,
    sanitize,
    sanitized_count,
    truncate_extras_value,
)

# ---------------------------------------------------------------------------
# Markdown 固有の定数（列構成は Excel: report-format.md 3.4 と同一）
# ---------------------------------------------------------------------------

LEVEL_TABLE_HEADERS = [
    "ケース ID",
    "revision",
    "タイトル",
    "優先度",
    "実行手順",
    "期待結果",
    "実際結果",
    "status",
    "reason",
    "実行時間(秒)",
    "エビデンス参照",
    "NG 詳細",
]


# ---------------------------------------------------------------------------
# Markdown 整形ヘルパ
# ---------------------------------------------------------------------------


def md_cell(value):
    """GFM 表セル用にエスケープする（パイプ・改行）。"""
    if value is None:
        return ""
    text = sanitize(str(value))
    return text.replace("|", "\\|").replace("\r\n", "\n").replace("\n", "<br>")


def md_table(headers, rows):
    lines = [
        "| " + " | ".join(md_cell(h) for h in headers) + " |",
        "|" + "|".join(" --- " for _ in headers) + "|",
    ]
    for row in rows:
        lines.append("| " + " | ".join(md_cell(v) for v in row) + " |")
    return lines


def md_evidence_paths(paths):
    """エビデンス相対パスのコード span 表記（複数件は <br> 区切り）。

    報告書の出力先（セッション作業領域）とエビデンス実体（テスト実績データディレクトリ）は
    別ツリーにあり相対リンクとして解決できないため、`[name](path)` のリンク構文は使わず
    Excel と対称なパス文字列表記に統一する（パスの基準はサマリ章の注記を参照）。
    """
    parts = []
    for p in paths or []:
        p = sanitize(str(p))
        parts.append(f"`{p}`")
    return "<br>".join(parts)


def format_test_data_lines(test_data, indent="  "):
    if isinstance(test_data, dict):
        return [f"{indent}- {sanitize(str(k))}: {sanitize(str(v))}" for k, v in test_data.items()]
    if test_data is None:
        return []
    return [f"{indent}- {sanitize(str(test_data))}"]


# ---------------------------------------------------------------------------
# 章生成（report-format.md 4 章の順序）
# ---------------------------------------------------------------------------


def build_markdown(model, generated_on):
    lines = []
    lines.append(f"# テスト報告書: {sanitize(model['target'])}")
    lines.append("")

    # 1. サマリ
    lines.append("## 1. サマリ")
    lines.append("")
    lines.append("### 1.1 基本情報")
    lines.append("")
    exec_dates = sorted({date_part(r.get("executed_at")) for r in model["runs"] if r.get("executed_at")})
    if not exec_dates:
        exec_range = ""
    elif len(exec_dates) == 1:
        exec_range = exec_dates[0]
    else:
        exec_range = f"{exec_dates[0]} 〜 {exec_dates[-1]}"
    lines += md_table(
        ["項目", "内容"],
        [
            ("対象", model["target"]),
            ("報告書生成日", generated_on),
            ("実行日", exec_range),
            ("run 数", len(model["runs"])),
        ],
    )
    lines.append("")
    # エビデンスパスの基準注記（必須出力。report_model.evidence_path_note）
    lines.append(sanitize(evidence_path_note(model["target"])))
    lines.append("")
    lines.append("### 1.2 run 情報")
    lines.append("")
    lines += md_table(
        ["run_id", "実行日時", "終了日時", "status", "mode", "対象ケース数", "environment"],
        [
            (
                r.get("run_id", ""),
                r.get("executed_at", ""),
                r.get("finished_at") or "",
                r.get("status", ""),
                r.get("mode", ""),
                len(r.get("scope") or []),
                r.get("environment", ""),
            )
            for r in model["runs"]
        ],
    )
    lines.append("")
    lines.append("### 1.3 レベル別集計（latest 採用）")
    lines.append("")
    agg_rows = [
        (
            level_label(lr["level"]),
            lr["target"],
            lr["pass"],
            lr["fail"],
            lr["blocked"],
            lr["skipped"],
            lr["na"],
        )
        for lr in model["level_rows"]
    ]
    t = model["total"]
    agg_rows.append(("合計", t["target"], t["pass"], t["fail"], t["blocked"], t["skipped"], t["na"]))
    lines += md_table(["レベル", "対象数", "pass", "fail", "blocked", "skipped", "na"], agg_rows)
    lines.append("")
    lines.append("### 1.4 総合判定")
    lines.append("")
    lines.append(f"**{model['verdict']}** — {VERDICT_DESCRIPTIONS[model['verdict']]}")
    lines.append("")
    lines.append("総合判定は実績の機械的集計であり、リリース可否・受入可否の判断は人間が行う。")
    lines.append("")

    # 2. 推移
    lines.append("## 2. 推移")
    lines.append("")
    lines.append("### 2.1 run 集計推移（時系列昇順）")
    lines.append("")
    lines += md_table(
        ["run_id", "実行日時", "mode", "pass", "fail", "blocked", "skipped", "na"],
        [
            (
                rr["run"].get("run_id", ""),
                rr["run"].get("executed_at", ""),
                rr["run"].get("mode", ""),
                rr["counts"]["pass"],
                rr["counts"]["fail"],
                rr["counts"]["blocked"],
                rr["counts"]["skipped"],
                rr["counts"]["na"],
            )
            for rr in model["run_rows"]
        ],
    )
    lines.append("")
    lines.append("### 2.2 ケース別推移（セル = 当該 run での status。未実行は空欄）")
    lines.append("")
    matrix_headers = ["ケース ID"] + [r.get("run_id", "") for r in model["runs"]]
    lines += md_table(matrix_headers, [tuple([m["case_id"]] + m["statuses"]) for m in model["matrix"]])
    lines.append("")

    # 3. レベル別セクション（実施レベルのみ・列構成は Excel と同一）
    lines.append("## 3. レベル別結果")
    lines.append("")
    lines.append(sanitize(evidence_path_note(model["target"])))
    lines.append("")
    for idx, level in enumerate(model["executed_levels"], start=1):
        lines.append(f"### 3.{idx} {level_label(level)}")
        lines.append("")
        # ユニット / 単体セクションのみ: 誤読防止の用語注記を見出し直下に 1 行出力する
        # （report-format.md 4 章。他レベルのセクションには不要）
        term_note = LEVEL_TERM_NOTES.get(level)
        if term_note:
            lines.append(sanitize(term_note))
            lines.append("")
        rows = []
        for case in model["active_cases"]:
            if case.get("level") != level:
                continue
            cid = case.get("id")
            detail = model["latest_detail"].get(cid)
            if not detail:
                continue
            ref = detail["ref"]
            result = detail["result"]
            defect = result.get("defect") or {}
            if defect:
                ng_summary = f"severity: {defect.get('severity', '')}（詳細は 4 章）"
            else:
                ng_summary = ""
            duration = result.get("duration_sec")
            rows.append(
                (
                    cid,
                    ref.get("case_revision", ""),
                    case.get("title", ""),
                    case.get("priority", ""),
                    join_lines(case.get("steps")),
                    case.get("expected", ""),
                    result.get("actual") or "",
                    ref.get("status", ""),
                    result.get("reason") or "",
                    format_duration(duration),
                    md_evidence_paths(result.get("evidence")),
                    ng_summary,
                )
            )
        lines += md_table(LEVEL_TABLE_HEADERS, rows)
        lines.append("")

    # 4. NG 詳細
    lines.append("## 4. NG 詳細")
    lines.append("")
    if not model["ng_rows"]:
        lines.append("なし")
        lines.append("")
    for idx, ng in enumerate(model["ng_rows"], start=1):
        defect = ng["defect"]
        lines.append(f"### 4.{idx} {ng['case_id']}: {sanitize(str(ng['title']))}")
        lines.append("")
        lines.append(f"- レベル: {level_label(ng['level'])}")
        lines.append(f"- severity: {ng['severity']}")
        lines.append("- 再現手順:")
        for step in defect.get("reproduction_steps") or []:
            lines.append(f"  - {sanitize(str(step))}")
        lines.append("- 検証データ:")
        lines += format_test_data_lines(defect.get("test_data"))
        lines.append("- エビデンス:")
        for path in defect.get("evidence") or ng["result"].get("evidence") or []:
            path = sanitize(str(path))
            lines.append(f"  - `{path}`")
        # 補足情報（defect.extras）: レベル別の拡張情報（stack_trace 等の長大値は切り詰め）
        extras = defect.get("extras")
        if isinstance(extras, dict) and extras:
            lines.append("- 補足情報:")
            for key, value in extras.items():
                text = sanitize(truncate_extras_value(value))
                text = text.replace("\r\n", "\n").replace("\n", "<br>")
                lines.append(f"  - {sanitize(str(key))}: {text}")
        lines.append("")

    # 5. 未確認事項（skipped 一覧 + ケース定義に存在しない実績 ID）
    lines.append("## 5. 未確認事項")
    lines.append("")
    if model["skipped_rows"]:
        lines += md_table(
            ["ケース ID", "レベル", "reason"],
            [(s["case_id"], level_label(s["level"]), s["reason"]) for s in model["skipped_rows"]],
        )
    else:
        lines.append("なし")
    lines.append("")
    if model["unknown_latest_ids"]:
        lines.append(
            "ケース定義に存在しない実績 ID（test-cases.yaml 未定義のため集計・明細の対象外。"
            "ケース定義の削除・改名等がないか確認すること）:"
        )
        lines.append("")
        for cid in model["unknown_latest_ids"]:
            lines.append(f"- `{sanitize(str(cid))}`")
        lines.append("")
    if model["unknown_level_case_ids"]:
        lines.append(
            "既知のテストレベル（levels.py の LEVEL_ORDER 8 値）以外の level を持つ実施済みケース"
            "（集計には unknown として含め総合判定にも反映済み。レベル別分類が想定外のため"
            "ケース定義の level 値を確認すること）:"
        )
        lines.append("")
        for cid in model["unknown_level_case_ids"]:
            lines.append(f"- `{sanitize(str(cid))}`")
        lines.append("")
    if model["masked_case_ids"]:
        lines.append(
            "機微情報マスキング適用ケース（既知シークレットパターンを検出し evidence-policy.md "
            "5 章の形式でマスクした。実績・エビデンスへの生値の混入経路を確認すること）:"
        )
        lines.append("")
        for cid in model["masked_case_ids"]:
            lines.append(f"- `{sanitize(str(cid))}`")
        lines.append("")
    # 所見・注記（annotations。実行結果に影響しない注釈。空なら小節ごと省略）
    if model["annotations"]:
        lines.append("### 所見・注記")
        lines.append("")
        lines.append(
            "実行結果に影響しない注釈（レビュー所見・テスト計画由来の未確認事項等。"
            "results_manager.py annotate 追記分）。"
        )
        lines.append("")
        lines += md_table(
            ["出所", "対象", "本文"],
            [(a["source"], annotation_target(a), a["text"]) for a in model["annotations"]],
        )
        lines.append("")

    # 6. 免責注記
    lines.append("## 6. 免責注記")
    lines.append("")
    lines += md_table(["項目", "注記"], build_disclaimer_rows(model))
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="deep-test テスト報告書（Markdown）生成")
    parser.add_argument("--results", required=True, help="test-results.yaml のパス")
    parser.add_argument("--cases", required=True, help="test-cases.yaml のパス")
    parser.add_argument("--output", required=True, help="出力 .md のパス")
    args = parser.parse_args()

    results_doc = load_yaml(args.results, "test-results.yaml")
    cases_doc = load_yaml(args.cases, "test-cases.yaml")
    model = build_model(cases_doc, results_doc)

    generated_on = date.today().strftime("%Y-%m-%d")
    content = build_markdown(model, generated_on)
    if "\u00a7" in content:
        # sanitize 網羅漏れの安全弁（禁止記号を最終出力に残さない）
        add_sanitized(content.count("\u00a7"))
        content = content.replace("\u00a7", "セクション")

    out_dir = os.path.dirname(os.path.abspath(args.output))
    os.makedirs(out_dir, exist_ok=True)
    with open(args.output, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    if sanitized_count():
        print(f"[WARN] 禁止記号（U+00A7）を {sanitized_count()} 箇所で代替表現に置換しました")
    total = model["total"]
    chapters = ["1. サマリ", "2. 推移", "3. レベル別結果", "4. NG 詳細", "5. 未確認事項", "6. 免責注記"]
    print(f"[DONE] Markdown 報告書を生成しました: {args.output}")
    print(f"章構成: {', '.join(chapters)}")
    print(f"レベル別セクション: {', '.join(level_label(lv) for lv in model['executed_levels'])}")
    print(f"総合判定: {model['verdict']}")
    print(
        "集計（latest）: 対象 {0} / pass {1} / fail {2} / blocked {3} / skipped {4} / na {5}".format(
            total["target"], total["pass"], total["fail"],
            total["blocked"], total["skipped"], total["na"],
        )
    )
    print(
        f"NG 件数: {len(model['ng_rows'])} / 未確認事項（skipped）: {len(model['skipped_rows'])}"
        f" / 所見・注記: {len(model['annotations'])}"
    )


if __name__ == "__main__":
    main()
