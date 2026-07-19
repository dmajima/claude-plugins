#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""deep-test 手動テスト実施指示書（手順書 / チャーターシート）生成スクリプト。

test-cases.yaml の手動系ケース（automation: manual-assist / exploratory）から、人間の実施者へ
渡す実施指示書 Markdown を 1 ファイル決定論生成する（LLM の手動転記では作らない。転記ミス・
マスキング漏れを構造的に防ぐ）。manual-assist ケースは手順書様式（前提条件・手順・期待結果・
検証データ・記入欄）、exploratory ケースはチャーターシート様式（チャーター・発見目標・
タイムボックス・セッション記入欄）で出力する。

起動主体は **オーケストレータ `test` のみ**。実行スキルは本スクリプトを起動せず、
オーケストレータから Skill args `manual-sheet={path}` で受領したパスを skipped の reason に
転記するだけとする（スクリプト実行の責務一元化）。用途は (1) 非対話時の一括生成
(2) 対話時の「後で実施」縮退時のオンデマンド生成 (3) 単独依頼（手順書だけ欲しい）。

- 手順書・チャーターシート様式の SSOT: <plugin>/references/manual-execution.md 8 章
- ケーススキーマの SSOT: <plugin>/references/yaml-schema-cases.md
- 機微情報マスキング形式の SSOT: <plugin>/references/evidence-policy.md 5 章
  （検出パターン群は test-report の report_model.py と同一。変更時は両方を同期すること）
- テストレベル表示名の SSOT: <plugin>/references/scripts/lib/levels.py

生成物は record による実績記録の代替ではない（本書への記入は実績記録ではない。記入結果は
deep-test へ回付し record 経由で記録する）。deprecated: true のケースは常に対象外。
ケースの出力順は test-cases.yaml の記載順を保持する（scope の並び制御はオーケストレータ側）。

exit code:
  0   正常終了（生成した手順書のパスを stdout に 1 行出力）
  1   一般エラー（test-cases.yaml 不在・YAML 解析失敗・スキーマ不整合・書き込み失敗）
  2   対象ケースなし（絞込の結果 0 件。ファイルは生成しない。オーケストレータの
      フェイルオープン判定用に「対象ケースなし」を stderr へ出力する）
  64  引数パースエラー（argparse 既定の 2 は「対象ケースなし」と衝突するため分離）
"""

import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

import argparse
import os
import re
from datetime import datetime

try:
    import yaml
except ImportError:
    print(
        "[ERROR] PyYAML がインストールされていません。"
        "venv を setup_venv.sh で構築し、venv の python で実行してください。",
        file=sys.stderr,
    )
    sys.exit(1)

# テストレベル表示名の共有モジュール（<plugin>/references/scripts/lib/levels.py）を import する。
# 本ファイル（skills/test/references/scripts/manual/）からプラグインルート直下の
# references/scripts/lib/ までの相対深度は 5 階層（../ を 5 個。results_manager.py と同じ）。
sys.path.insert(
    0,
    os.path.normpath(
        os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "..", "..", "..", "..", "references", "scripts", "lib",
        )
    ),
)
from levels import LEVEL_DISPLAY_NAMES  # noqa: E402

EXIT_OK = 0
EXIT_ERROR = 1
EXIT_NO_CASES = 2
EXIT_USAGE = 64  # 引数パースエラー（argparse 既定の 2 は EXIT_NO_CASES と衝突するため分離）

SCHEMA_VERSION = 1
MANUAL_AUTOMATIONS = ("manual-assist", "exploratory")
DEFAULT_TIMEOUT_SEC = 120

# 記入欄の空欄プレースホルダ（実施者が手書き / 上書き記入する）
BLANK = "____________"


# ---------------------------------------------------------------------------
# 共通ユーティリティ
# ---------------------------------------------------------------------------

def err(msg):
    print(msg, file=sys.stderr)


def warn(msg):
    err(f"[WARN] {msg}")


def info(msg):
    err(f"[INFO] {msg}")


def die(msg, code=EXIT_ERROR):
    err(f"[ERROR] {msg}")
    sys.exit(code)


def now_iso():
    return datetime.now().astimezone().isoformat(timespec="seconds")


def norm_path(path):
    """パス区切りをスラッシュに統一する（stdout の出力パス表記揺れ防止）。"""
    return str(path).replace(os.sep, "/")


# ---------------------------------------------------------------------------
# 機微情報マスキング（決定論的二次防御。evidence-policy.md 5 章）
# report_model.py（test-report スキル）と同一のパターン群・マスク形式。変更時は両方を同期する。
# ---------------------------------------------------------------------------

# 既知シークレットの正規表現パターン（マッチ全体をマスクする）
_SECRET_PATTERNS = [
    re.compile(r"sk-[A-Za-z0-9]{16,}"),  # OpenAI API キー
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),  # GitHub トークン（ghp/gho/ghu/ghs/ghr）
    re.compile(r"xox[bpars]-[A-Za-z0-9-]{10,}"),  # Slack トークン
    re.compile(r"AKIA[A-Z0-9]{16}"),  # AWS アクセスキー ID
    re.compile(r"AIza[A-Za-z0-9_-]{35}"),  # Google API キー
    re.compile(r"glpat-[A-Za-z0-9_-]{20,}"),  # GitLab Personal Access Token
    re.compile(  # JWT（header.payload.signature）
        r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}"
    ),
]

# プレフィクス保持パターン（グループ 1 のプレフィクスは残し、グループ 2 の値のみマスクする）
_PREFIXED_SECRET_PATTERNS = [
    re.compile(r"(Bearer\s+)([A-Za-z0-9._-]{16,})"),  # HTTP Bearer トークン
    re.compile(r"(password\s*[:=]\s*)(\S+)", re.IGNORECASE),  # password 代入形式
]

# PEM 秘密鍵ブロック（END 行まで。END 行が欠けた断片は BEGIN 行以降すべてをマスクする）
_PEM_BLOCK_PATTERN = re.compile(
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----"
    r"(?:[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----|[\s\S]*)"
)

# 転記時のマスク・禁止記号置換の累計（stderr への件数報告に使う）
_TRANSCRIBE_STATE = {"masked": 0, "sanitized": 0}


def mask_secret_value(value):
    """evidence-policy.md 5 章のマスク形式（9 文字以上: 先頭 4 + **** + 末尾 4 / 8 文字以下: 全体）。"""
    if len(value) <= 8:
        return "********"
    return value[:4] + "****" + value[-4:]


def mask_secrets_in_text(text):
    """既知シークレットパターンをマスクした文字列と置換件数のタプルを返す。"""
    if not isinstance(text, str) or not text:
        return text, 0
    counter = {"count": 0}

    def repl_whole(match):
        counter["count"] += 1
        return mask_secret_value(match.group(0))

    def repl_prefixed(match):
        counter["count"] += 1
        return match.group(1) + mask_secret_value(match.group(2))

    masked = _PEM_BLOCK_PATTERN.sub(repl_whole, text)
    for pattern in _SECRET_PATTERNS:
        masked = pattern.sub(repl_whole, masked)
    for pattern in _PREFIXED_SECRET_PATTERNS:
        masked = pattern.sub(repl_prefixed, masked)
    return masked, counter["count"]


# ---------------------------------------------------------------------------
# 転記ヘルパ（マスキング + 禁止記号置換 + 1 行化）
# ---------------------------------------------------------------------------

def transcribe(value):
    """ケースのフィールド値を手順書へ転記できる 1 行文字列にする。

    マスキング（evidence-policy.md 5 章）と禁止記号 U+00A7 の置換（document-rules 準拠）を
    適用し、改行は空白に潰す（リスト項目・表セルの構造を壊さないため）。
    """
    if value is None:
        return ""
    text = str(value)
    masked, n = mask_secrets_in_text(text)
    _TRANSCRIBE_STATE["masked"] += n
    forbidden = chr(0xA7)  # 禁止記号 U+00A7（セクション記号）。ソース中に文字リテラルでは書かない
    if forbidden in masked:
        _TRANSCRIBE_STATE["sanitized"] += masked.count(forbidden)
        masked = masked.replace(forbidden, "セクション")
    return " ".join(masked.splitlines()) if "\n" in masked else masked


def cell(value):
    """Markdown 表のセル用転記（パイプをエスケープする）。"""
    return transcribe(value).replace("|", "\\|")


def level_label(level):
    """レベルの表示形式「{日本語表示名}（{level}）」を返す（例: 単体（functional））。"""
    if level is None:
        return "-"
    name = LEVEL_DISPLAY_NAMES.get(level)
    return f"{name}（{level}）" if name else str(level)


def timeout_label(case):
    """manual-assist のタイムアウト表示（秒）。"""
    return f"{case.get('timeout_sec', DEFAULT_TIMEOUT_SEC)} 秒"


def timebox_label(case):
    """exploratory のタイムボックス表示（分）。60 で割り切れない場合は秒を併記する。"""
    sec = case.get("timeout_sec", DEFAULT_TIMEOUT_SEC)
    if isinstance(sec, int) and sec > 0 and sec % 60 == 0:
        return f"{sec // 60} 分"
    return f"{sec} 秒（約 {sec / 60:.1f} 分）" if isinstance(sec, (int, float)) else str(sec)


def numbered_lines(items, indent="  "):
    """steps を番号付きで転記する行リストを返す（既に番号付きの文字列は二重付番しない）。"""
    lines = []
    for i, item in enumerate(items, 1):
        text = transcribe(item)
        if re.match(r"^\s*\d+[.)）]\s*", text):
            lines.append(f"{indent}{text}")
        else:
            lines.append(f"{indent}{i}. {text}")
    return lines


def bulleted_lines(items, indent="  "):
    """preconditions / postconditions を番号なしリストで転記する行リストを返す。"""
    return [f"{indent}- {transcribe(item)}" for item in items]


def field_block(label, value):
    """任意フィールドの転記行を返す（リスト / マップ / スカラー / 欠落（なし）を吸収する）。"""
    if value is None or value == [] or value == {}:
        return [f"- {label}: （なし）"]
    if isinstance(value, list):
        return [f"- {label}:"] + bulleted_lines(value)
    if isinstance(value, dict):
        return [f"- {label}:"] + [f"  - {transcribe(k)}: {transcribe(v)}" for k, v in value.items()]
    return [f"- {label}: {transcribe(value)}"]


# ---------------------------------------------------------------------------
# test-cases.yaml 読み込み（results_manager.py と同型の統一診断メッセージ）
# ---------------------------------------------------------------------------

def load_cases(path):
    if not os.path.isfile(path):
        die(f"test-cases.yaml が見つかりません: {path}")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
    except (yaml.YAMLError, UnicodeDecodeError, OSError) as e:
        die(f"test-cases.yaml の読み込み / YAML 解析に失敗しました（UTF-8 想定）: {path}\n{e}")
    if not isinstance(data, dict):
        die(f"test-cases.yaml のスキーマ不整合（トップレベルはマップ）: {path}")
    meta = data.get("meta")
    if not isinstance(meta, dict) or meta.get("schema_version") != SCHEMA_VERSION:
        die(f"test-cases.yaml のスキーマ不整合（meta.schema_version={SCHEMA_VERSION} 必須）: {path}")
    cases = data.get("cases")
    if cases is None:
        cases = []
    if not isinstance(cases, list) or not all(isinstance(c, dict) for c in cases):
        die(f"test-cases.yaml のスキーマ不整合（cases はマップのリスト）: {path}")
    data["cases"] = cases
    return data


def select_manual_cases(cases, automations, ids):
    """手動系ケースを絞り込む（deprecated は常に除外。出力順は記載順を保持）。"""
    id_filter = set(ids) if ids else None
    known_ids = {c.get("id") for c in cases}
    if id_filter:
        for cid in sorted(id_filter - known_ids):
            warn(f"test-cases.yaml に存在しないケース ID を除外しました: {cid}")
    selected = []
    for case in cases:
        if case.get("deprecated") is True:
            continue
        if case.get("automation") not in automations:
            continue
        if id_filter is not None and case.get("id") not in id_filter:
            continue
        selected.append(case)
    return selected


# ---------------------------------------------------------------------------
# Markdown 生成（様式の SSOT は references/manual-execution.md 8 章）
# ---------------------------------------------------------------------------

def build_header(target, automations, ids, selected, generated_at):
    ma_count = sum(1 for c in selected if c.get("automation") == "manual-assist")
    ex_count = sum(1 for c in selected if c.get("automation") == "exploratory")
    ids_label = ", ".join(ids) if ids else "（指定なし）"
    lines = [
        "# 手動テスト実施指示書",
        "",
        "> **注意**: 記入結果は deep-test へ回付し record 経由で実績記録する。"
        "**本書への記入は実績記録ではない**。",
        "",
        "| 項目 | 内容 |",
        "|---|---|",
        f"| 対象 | {cell(target)} |",
        f"| 生成日時 | {generated_at} |",
        f"| 絞込条件 | automation = {', '.join(automations)} / ids = {cell(ids_label)} |",
        f"| 対象ケース数 | {len(selected)} 件"
        f"（manual-assist {ma_count} 件 / exploratory {ex_count} 件） |",
        "",
        "## 対象ケース一覧（revision）",
        "",
        "| ケース ID | revision | レベル | automation | タイトル |",
        "|---|---|---|---|---|",
    ]
    for case in selected:
        lines.append(
            f"| {cell(case.get('id'))} | {cell(case.get('revision'))} "
            f"| {cell(level_label(case.get('level')))} | {cell(case.get('automation'))} "
            f"| {cell(case.get('title'))} |"
        )
    lines.append("")
    return lines


def build_manual_assist_section(case):
    """manual-assist ケース節（manual-execution.md 8.2 の様式）。"""
    lines = [
        f"## {transcribe(case.get('id'))}: {transcribe(case.get('title'))}",
        "",
        "| ケース ID | revision | レベル | 優先度 | automation | タイムアウト |",
        "|---|---|---|---|---|---|",
        f"| {cell(case.get('id'))} | {cell(case.get('revision'))} "
        f"| {cell(level_label(case.get('level')))} | {cell(case.get('priority'))} "
        f"| manual-assist | {timeout_label(case)} |",
        "",
    ]
    preconditions = case.get("preconditions")
    lines += ["- 前提条件:"] + bulleted_lines(preconditions) if preconditions else ["- 前提条件: （なし）"]
    steps = case.get("steps") or []
    lines += ["- 手順:"] + numbered_lines(steps)
    lines += [f"- 期待結果: {transcribe(case.get('expected'))}"]
    lines += field_block("検証データ", case.get("data"))
    lines += field_block("事後処理", case.get("postconditions"))
    lines += [
        "",
        "### 記入欄（実施後に deep-test へ回付してください。本書への記入は実績記録ではありません）",
        "",
        "| 項目 | 記入 |",
        "|---|---|",
        "| 結果（いずれかに丸） | pass / fail / blocked |",
        f"| 実施者 / 実施日時 | {BLANK} / {BLANK} |",
        f"| 実測値（性能ケースのみ） | {BLANK} |",
        f"| 実際の結果（fail 時は必須） | {BLANK} |",
        f"| エビデンスの所在（ファイル名・保存先） | {BLANK} |",
        "",
    ]
    return lines


def build_exploratory_section(case):
    """exploratory ケース節 = チャーターシート（manual-execution.md 8.3 の様式）。"""
    lines = [
        f"## {transcribe(case.get('id'))}: {transcribe(case.get('title'))}",
        "",
        "| ケース ID | revision | レベル | 優先度 | automation | タイムボックス |",
        "|---|---|---|---|---|---|",
        f"| {cell(case.get('id'))} | {cell(case.get('revision'))} "
        f"| {cell(level_label(case.get('level')))} | {cell(case.get('priority'))} "
        f"| exploratory | {timebox_label(case)} |",
        "",
        "> タイムボックス満了はセッションの正常終了として結果判定へ進む"
        "（超過 = blocked の規約は適用しない）。",
        "",
    ]
    steps = case.get("steps") or []
    lines += ["- チャーター（探索指針）:"] + numbered_lines(steps)
    lines += [f"- 発見目標・完了条件: {transcribe(case.get('expected'))}"]
    preconditions = case.get("preconditions")
    lines += ["- 前提条件:"] + bulleted_lines(preconditions) if preconditions else ["- 前提条件: （なし）"]
    lines += field_block("検証データ", case.get("data"))
    lines += field_block("事後処理", case.get("postconditions"))
    lines += [
        "",
        "### セッション記入欄"
        "（実施後に deep-test へ回付してください。本書への記入は実績記録ではありません）",
        "",
        "| 項目 | 記入 |",
        "|---|---|",
        f"| セッション開始 / 終了日時 | {BLANK} / {BLANK} |",
        f"| 実施者 | {BLANK} |",
        "| 総合結果（いずれかに丸） | pass（重大発見なし・完遂） / fail（欠陥発見） "
        "/ blocked（探索不能） |",
        "",
        "#### セッションノート（何を試したか）",
        "",
        f"- {BLANK}",
        f"- {BLANK}",
        "",
        "#### 発見事象一覧（再現手順メモ付き）",
        "",
        "| # | 発見事象 | 再現手順メモ |",
        "|---|---|---|",
        f"| 1 | {BLANK} | {BLANK} |",
        f"| 2 | {BLANK} | {BLANK} |",
        f"| 3 | {BLANK} | {BLANK} |",
        "",
        "#### PROOF 振り返り（Past / Results / Obstacles / Outlook / Feelings）",
        "",
        "| 観点 | 記入 |",
        "|---|---|",
        f"| Past（何をしたか） | {BLANK} |",
        f"| Results（何を得たか） | {BLANK} |",
        f"| Obstacles（何に阻まれたか） | {BLANK} |",
        f"| Outlook（次に何をすべきか） | {BLANK} |",
        f"| Feelings（どう感じたか） | {BLANK} |",
        "",
    ]
    return lines


def build_sheet(target, automations, ids, selected, generated_at):
    lines = build_header(target, automations, ids, selected, generated_at)
    for case in selected:
        lines.append("---")
        lines.append("")
        if case.get("automation") == "exploratory":
            lines += build_exploratory_section(case)
        else:
            lines += build_manual_assist_section(case)
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# エントリポイント
# ---------------------------------------------------------------------------

class UsageErrorParser(argparse.ArgumentParser):
    """引数パースエラーを exit code 64 で終了させる ArgumentParser。

    argparse 既定のパースエラーは exit code 2 だが、本スクリプトでは 2 を
    EXIT_NO_CASES（対象ケースなし）に割り当てているため衝突する。
    引数の構文エラーは EXIT_USAGE=64（sysexits.h の EX_USAGE 相当）に分離する。
    """

    def error(self, message):
        self.print_usage(sys.stderr)
        err(f"[ERROR] 引数が不正です: {message}")
        sys.exit(EXIT_USAGE)


def build_parser():
    parser = UsageErrorParser(
        prog="generate_manual_sheet.py",
        description=(
            "test-cases.yaml の手動系ケース（manual-assist / exploratory）から"
            "実施指示書 Markdown を生成する（起動主体はオーケストレータ test のみ）"
        ),
    )
    parser.add_argument("--cases", required=True, help="test-cases.yaml のパス")
    parser.add_argument(
        "--ids",
        default=None,
        help="対象ケース ID の CSV（例: TC-FUNC-002,TC-UAT-003。省略時は絞込なし）",
    )
    parser.add_argument(
        "--automation",
        choices=("manual-assist", "exploratory", "both"),
        default="both",
        help="対象とする automation（既定 both = manual-assist と exploratory の両方）",
    )
    parser.add_argument("--out", required=True, help="出力する手順書 Markdown のパス")
    parser.add_argument(
        "--target",
        default=None,
        help="対象名（ヘッダ表示用。省略時は test-cases.yaml の meta.target を使う）",
    )
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)

    if args.automation == "both":
        automations = list(MANUAL_AUTOMATIONS)
    else:
        automations = [args.automation]

    ids = None
    if args.ids is not None:
        ids = [token.strip() for token in args.ids.split(",") if token.strip()]
        if not ids:
            die("--ids に有効なケース ID がありません（カンマ区切りで指定してください）", EXIT_USAGE)

    cases_data = load_cases(args.cases)
    target = args.target or cases_data.get("meta", {}).get("target") or "-"

    selected = select_manual_cases(cases_data["cases"], automations, ids)
    if not selected:
        err(
            "対象ケースなし: 絞込条件に一致する手動系ケース"
            f"（automation = {', '.join(automations)}）が 0 件のため手順書を生成しません。"
        )
        sys.exit(EXIT_NO_CASES)

    content = build_sheet(target, automations, ids, selected, now_iso())

    out_dir = os.path.dirname(os.path.abspath(args.out))
    try:
        os.makedirs(out_dir, exist_ok=True)
        with open(args.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
    except OSError as e:
        die(f"手順書の書き込みに失敗しました: {args.out}\n{e}")

    if _TRANSCRIBE_STATE["masked"]:
        info(f"転記フィールドに機微情報パターンを検出しマスクしました（計 {_TRANSCRIBE_STATE['masked']} 件）")
    if _TRANSCRIBE_STATE["sanitized"]:
        info(f"転記フィールドの禁止記号を置換しました（計 {_TRANSCRIBE_STATE['sanitized']} 件）")
    info(
        f"手順書を生成しました（対象 {len(selected)} 件: "
        f"manual-assist {sum(1 for c in selected if c.get('automation') == 'manual-assist')} 件 / "
        f"exploratory {sum(1 for c in selected if c.get('automation') == 'exploratory')} 件）"
    )
    print(norm_path(args.out))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
