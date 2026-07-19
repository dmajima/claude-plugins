#!/usr/bin/env python3
"""deep-test / test-report: 報告書生成の共通データモデルモジュール。

generate_excel.py / generate_markdown.py が共有する読み込み・集計・整形ロジックを
一元化する（両スクリプト間の集計規則のズレを構造的に防ぐ DRY モジュール）。
両生成スクリプトと同ディレクトリに配置し、各スクリプトから
`sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))` 方式で import される。

- フォーマット SSOT: プラグイン共通 references/report-format.md
- 集計規則: ケースごとの最新 run 結果（latest セクション）を採用（references/retest-policy.md）
- deprecated: true のケースは集計・明細・推移の対象外
- latest に test-cases.yaml 未定義の実績 ID がある場合は黙殺せず stdout に [WARN] を出力し、
  モデルの unknown_latest_ids として報告書の未確認事項に記載させる
- 転載テキストには既知シークレットパターンの決定論的マスキングを適用する
  （apply_secret_masking。evidence-auditor の代替ではない二次防御。evidence-policy.md 5 章）
- 本モジュールは import 時に出力しない（stdout/stderr の UTF-8 再構成は各エントリスクリプトが実施）
"""

import os
import re
import sys

import yaml

# テストレベル定数の共有モジュール（<plugin>/references/scripts/lib/levels.py）を import する。
# 本ファイル（skills/test-report/references/scripts/report/）からプラグインルート直下の
# references/scripts/lib/ までの相対深度は 5 階層（../ を 5 個）。
# generate_excel.py / generate_markdown.py はこれらを本モジュール経由で参照する
# （import されたシンボルは本モジュールの属性となるため from report_model import ... で解決可能）。
sys.path.insert(
    0,
    os.path.normpath(
        os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "..", "..", "..", "..", "references", "scripts", "lib",
        )
    ),
)
from levels import (  # noqa: E402
    LEVEL_DISPLAY_NAMES,
    LEVEL_ORDER,
    LEVEL_TERM_NOTES,
)

# ---------------------------------------------------------------------------
# 共通定数（report-format.md 準拠）
# ---------------------------------------------------------------------------

# 実績 YAML（test-results.yaml / test-cases.yaml）の期待スキーマ版数（yaml-schema.md）
SCHEMA_VERSION = 1

# LEVEL_ORDER / LEVEL_DISPLAY_NAMES / LEVEL_TERM_NOTES はテストレベル定数の共有モジュール
# levels.py（コード SSOT。散文 SSOT は references/test-levels.md）から import している（上部参照）。
# レベルの追加・改名・表示名変更・用語注記変更は levels.py と test-levels.md の両方を同時更新すること。

STATUS_ORDER = ["pass", "fail", "blocked", "skipped", "na"]

# 実行主体（executed_by）の自動 / 手動分類キー（report-format.md 3.2 レベル別集計）。
# human-assisted（人間の実施・申告に基づく記録）のみ manual、それ以外の enum 4 値
# （playwright-mcp / playwright-test / test-framework / api）は auto に分類する
EXECUTION_CLASS_KEYS = ["auto", "manual"]


def classify_executed_by(executed_by):
    """結果レコードの executed_by を自動（auto）/ 手動（manual）に分類する。"""
    return "manual" if str(executed_by or "") == "human-assisted" else "auto"

# 既知のテストレベル（levels.py の LEVEL_ORDER）以外の level をまとめる集計行のキー。
# 未知レベルのケースを verdict・レベル別集計から静かに脱落させず、本キーの行に合算する。
UNKNOWN_LEVEL_KEY = "unknown"

# report-format.md 3.2 総合判定の条件説明
VERDICT_DESCRIPTIONS = {
    "PASS": "latest 集計で fail = 0 かつ blocked = 0 かつ skipped = 0（na は対象外として併記）",
    "FAIL": "fail が 1 件以上",
    "INCOMPLETE": "fail = 0 だが blocked または skipped が 1 件以上（未確認が残る）",
}

# report-format.md 6 章 免責注記（6 項目必須。実施有無に関わらず削除しない）
DISCLAIMERS = [
    ("UAT", "UAT 支援は検証支援であり、受入判断は人間（発注者・業務部門）が実施する。"),
    (
        "性能",
        "性能テストは単一セッションの応答時間計測が中心であり、"
        "多重負荷試験は外部負荷ツール検出時のみの条件付き実施である。",
    ),
    (
        "セキュリティ",
        "セキュリティテストは OWASP 観点の動的チェックであり、"
        "ペネトレーションテストの代替ではない。",
    ),
    (
        "再テスト",
        "ng-only 再テストは回帰テストの代替ではない"
        "（修正の副作用検出には full 再テストを推奨する）。",
    ),
    (
        "用語",
        "本報告書の『ユニットテスト』はコードレベルの自動テスト、"
        "『単体テスト』は実アプリの画面・機能単位のテストを指す"
        "（本プラグイン独自の区分であり、JSTQB/ISTQB の呼称とは異なる）。",
    ),
    (
        "手動",
        "executed_by: human-assisted の結果は人間の実施・申告に基づく記録であり、"
        "機械検証（自動実行）とは実行主体が異なる（実行主体列・サマリ内訳で区別する）。",
    ),
]

# 禁止記号（U+00A7）の置換件数カウンタ（両生成スクリプトで共有）
SANITIZED = {"count": 0}


def sanitize(value):
    """禁止記号（U+00A7 セクション記号）を代替表現へ置換する（document-rules 準拠）。"""
    forbidden = "\u00a7"
    if isinstance(value, str) and forbidden in value:
        SANITIZED["count"] += value.count(forbidden)
        return value.replace(forbidden, "セクション")
    return value


def sanitized_count():
    """これまでに置換した禁止記号の件数を返す。"""
    return SANITIZED["count"]


def add_sanitized(count):
    """生成スクリプト側の安全弁で追加置換した件数をカウンタへ加算する。"""
    SANITIZED["count"] += count


# ---------------------------------------------------------------------------
# 機微情報マスキング（決定論的二次防御。evidence-policy.md 5 章）
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


def _mask_str_list(values):
    """文字列リストの各要素をその場でマスクし、置換件数を返す。"""
    if not isinstance(values, list):
        return 0
    count = 0
    for i, item in enumerate(values):
        if isinstance(item, str):
            masked, n = mask_secrets_in_text(item)
            if n:
                values[i] = masked
                count += n
    return count


def _mask_mapping_values(mapping):
    """マップ値をその場でマスクし、置換件数を返す（test_data / extras 用）。

    値単独では一致せず、キー名との組み合わせでのみ一致するパターン
    （例: キー password + 値のみの場合の password 代入形式）も検出する。
    """
    count = 0
    for key, value in list(mapping.items()):
        if isinstance(value, dict):
            count += _mask_mapping_values(value)
            continue
        if isinstance(value, list):
            count += _mask_str_list(value)
            continue
        if not isinstance(value, str):
            continue
        masked, n = mask_secrets_in_text(value)
        if n == 0 and isinstance(key, str):
            prefix = f"{key}: "
            combined, combined_count = mask_secrets_in_text(prefix + value)
            if combined_count:
                masked = combined[len(prefix):] if combined.startswith(prefix) else combined
                n = combined_count
        if n:
            mapping[key] = masked
            count += n
    return count


def _mask_result_fields(result):
    """結果レコード 1 件の転載対象フィールドをその場でマスクし、置換件数を返す。"""
    if not isinstance(result, dict):
        return 0
    count = 0
    for key in ("actual", "reason"):
        value = result.get(key)
        if isinstance(value, str):
            masked, n = mask_secrets_in_text(value)
            if n:
                result[key] = masked
                count += n
    count += _mask_str_list(result.get("evidence"))
    defect = result.get("defect")
    if isinstance(defect, dict):
        count += _mask_str_list(defect.get("reproduction_steps"))
        count += _mask_str_list(defect.get("evidence"))
        test_data = defect.get("test_data")
        if isinstance(test_data, str):
            masked, n = mask_secrets_in_text(test_data)
            if n:
                defect["test_data"] = masked
                count += n
        elif isinstance(test_data, dict):
            count += _mask_mapping_values(test_data)
        extras = defect.get("extras")
        if isinstance(extras, dict):
            count += _mask_mapping_values(extras)
    return count


def apply_secret_masking(latest_detail):
    """報告書へ転載される全テキストフィールドへ機微情報マスキングを適用する。

    既知シークレットパターン（API キー・各種トークン・JWT・秘密鍵・password 代入形式）に
    一致した値を evidence-policy.md 5 章のマスク形式へ置換する **決定論的な二次防御
    （defense-in-depth）** であり、evidence-auditor（LLM によるエビデンス監査）の
    代替ではない（未知パターン・文脈依存の機微情報は本関数では検出できない）。

    対象フィールド: actual / reason / evidence 表記 / defect.reproduction_steps /
    defect.test_data / defect.evidence 表記 / defect.extras 値。
    マスク適用が発生したケースは stdout に [MASKED] を出力し、呼び出し元（build_model）が
    masked_case_ids としてモデルへ載せ、報告書の未確認事項に記載させる。
    """
    masked_ids = []
    for case_id in sorted(latest_detail, key=str):
        if _mask_result_fields(latest_detail[case_id]["result"]):
            masked_ids.append(str(case_id))
            print(f"[MASKED] {case_id} のフィールドに機微情報パターンを検出しマスクしました")
    return masked_ids


def evidence_path_note(target, results_path=None):
    """エビデンス参照パスの基準に関する注記（両形式のサマリ部に必ず出力する）。

    報告書の出力先（セッション作業領域）とエビデンス実体（テスト実績データディレクトリ）は
    別ツリーにあるため、報告書からの相対リンクとして解決できないことを明示する。

    基準ディレクトリは results ファイル（test-results.yaml）の実パスから導出する
    （エビデンスは実績 YAML と同じ {target-slug}/ 直下基準のため。data-locations.md）。
    これにより非既定 base・home フォールバック配置でも注記と実配置が一致する。
    results_path 未指定・導出不能時は、既定配置のパス表記に「既定配置の場合」を付す
    フェイルセーフへ縮退する（従来の第 1 引数のみの呼出シグネチャとも互換）。
    """
    base_dir = ""
    if results_path:
        try:
            raw = str(results_path).strip()
            # 呼出時の表記（相対/絶対）を保ったまま親ディレクトリを取る。
            # ファイル名のみ指定（親が空）の場合は絶対パス経由で解決する
            base_dir = os.path.dirname(raw) or os.path.dirname(os.path.abspath(raw))
        except (TypeError, ValueError, OSError):
            base_dir = ""
    if base_dir:
        display = base_dir.replace("\\", "/").rstrip("/") + "/"
        return (
            "エビデンス参照はテスト実績データディレクトリ"
            f"（{display}）基準の相対パスであり、"
            "本報告書からの相対リンクではない。"
        )
    slug = str(target).strip() if target else ""
    slug = slug or "{target-slug}"
    return (
        "エビデンス参照はテスト実績データディレクトリ"
        f"（既定配置の場合 .claude/.local/plugins/deep-test/{slug}/）基準の相対パスであり、"
        "本報告書からの相対リンクではない。"
    )


# ---------------------------------------------------------------------------
# データ読み込み・集計（latest 採用）
# ---------------------------------------------------------------------------


def die_schema(detail):
    """スキーマ不整合を統一メッセージで報告し exit 2 で終了する（report_model 共通）。"""
    print(f"[ERROR] {detail}", file=sys.stderr)
    sys.exit(2)


def load_yaml(path, label):
    if not os.path.isfile(path):
        print(f"[ERROR] {label} が見つかりません: {path}", file=sys.stderr)
        sys.exit(2)
    with open(path, "r", encoding="utf-8") as f:
        try:
            doc = yaml.safe_load(f)
        except yaml.YAMLError as exc:
            print(f"[ERROR] {label} の YAML 解析に失敗しました: {exc}", file=sys.stderr)
            sys.exit(2)
    if not isinstance(doc, dict):
        print(f"[ERROR] {label} の内容が不正です（マッピングではありません）: {path}", file=sys.stderr)
        sys.exit(2)
    # スキーマ版数の検証（results_manager.py と同水準。SSOT は yaml-schema.md）
    meta = doc.get("meta")
    if not isinstance(meta, dict):
        print(f"[ERROR] {label} のスキーマ不整合（meta がマップではありません）: {path}", file=sys.stderr)
        sys.exit(2)
    if meta.get("schema_version") != SCHEMA_VERSION:
        print(
            f"[ERROR] {label} のスキーマ版数が不一致です（期待 {SCHEMA_VERSION} / "
            f"実際 {meta.get('schema_version')}）: {path}",
            file=sys.stderr,
        )
        sys.exit(2)
    return doc


def build_model(cases_doc, results_doc):
    """両 YAML から報告書用のデータモデルを構築する（deprecated 除外・latest 採用）。"""
    # コンテナ型の検証（results_manager.py の load_results / load_cases と同水準）。
    # list であるべき箇所が非 list、latest が非 dict の場合に未捕捉の TypeError を送出せず、
    # 明確な診断メッセージで die する（meta.schema_version は load_yaml が既に検証済み）。
    cases_raw = cases_doc.get("cases")
    if cases_raw is None:
        cases_raw = []
    if not isinstance(cases_raw, list):
        die_schema("test-cases.yaml のスキーマ不整合: cases はリストである必要があります")

    runs_raw = results_doc.get("runs")
    if runs_raw is None:
        runs_raw = []
    if not isinstance(runs_raw, list):
        die_schema("test-results.yaml のスキーマ不整合: runs はリストである必要があります")

    results_raw = results_doc.get("results")
    if results_raw is None:
        results_raw = []
    if not isinstance(results_raw, list):
        die_schema("test-results.yaml のスキーマ不整合: results はリストである必要があります")

    latest = results_doc.get("latest")
    if latest is None:
        latest = {}
    if not isinstance(latest, dict):
        die_schema("test-results.yaml のスキーマ不整合: latest はマップである必要があります")

    annotations_raw = results_doc.get("annotations")
    if annotations_raw is not None and not isinstance(annotations_raw, list):
        die_schema("test-results.yaml のスキーマ不整合: annotations はリストである必要があります")

    all_cases = [c for c in cases_raw if isinstance(c, dict)]
    active_cases = sorted(
        [c for c in all_cases if not c.get("deprecated", False)],
        key=lambda c: str(c.get("id", "")),
    )
    case_by_id = {c.get("id"): c for c in active_cases}

    runs = sorted(
        [r for r in runs_raw if isinstance(r, dict)],
        key=lambda r: str(r.get("run_id", "")),
    )
    if not runs:
        print("[ERROR] test-results.yaml に run がありません（報告対象がありません）", file=sys.stderr)
        sys.exit(2)
    results = [r for r in results_raw if isinstance(r, dict)]

    # ケース定義（deprecated 含む）に存在しない実績 ID の検出（黙殺しない）
    all_ids = {c.get("id") for c in all_cases}
    unknown_latest_ids = sorted(str(cid) for cid in latest if cid not in all_ids)
    if unknown_latest_ids:
        print(
            "[WARN] test-cases.yaml のケース定義に存在しない実績 ID を検出しました"
            "（集計・明細の対象外。報告書の未確認事項に記載します）: "
            + ", ".join(unknown_latest_ids)
        )

    # (case_id, run_id) → 結果レコード（同一キーは後勝ち）
    result_index = {}
    for entry in results:
        result_index[(entry.get("case_id"), entry.get("run_id"))] = entry

    # ケースごとの最新結果詳細（deprecated・未知ケースは除外）
    latest_detail = {}
    for case_id, ref in latest.items():
        if case_id not in case_by_id or not isinstance(ref, dict):
            continue
        latest_detail[case_id] = {
            "ref": ref,
            "result": result_index.get((case_id, ref.get("run_id"))) or {},
        }

    # 機微情報マスキング（決定論的二次防御。evidence-auditor の代替ではない）。
    # ng_rows / skipped_rows は latest_detail から文字列を複製するため、
    # 転載データ構築前のこの位置（build_model 内の共通経路）で適用する
    masked_case_ids = apply_secret_masking(latest_detail)

    # 所見・注記（annotations）: 実行結果に影響しない注釈（results_manager.py annotate 追記分）。
    # 報告書へ転載するため本文（text）も機微情報マスキングの適用対象に含める
    annotations = []
    for i, entry in enumerate(annotations_raw or []):
        if not isinstance(entry, dict):
            print(f"[WARN] annotations[{i}] がマップではないため転載をスキップしました")
            continue
        text = entry.get("text")
        if not isinstance(text, str) or not text.strip():
            print(f"[WARN] annotations[{i}] の text が空のため転載をスキップしました")
            continue
        masked_text, mask_count = mask_secrets_in_text(text)
        if mask_count:
            masked_case_ids.append(f"annotations[{i + 1}]")
            print(f"[MASKED] annotations[{i + 1}] の本文に機微情報パターンを検出しマスクしました")
        annotations.append(
            {
                "case_id": entry.get("case_id"),
                "run_id": entry.get("run_id"),
                "source": str(entry.get("source") or ""),
                "text": masked_text,
            }
        )

    def sort_key(case_id):
        case = case_by_id.get(case_id) or {}
        level = case.get("level")
        idx = LEVEL_ORDER.index(level) if level in LEVEL_ORDER else len(LEVEL_ORDER)
        return (idx, str(case_id))

    # レベル別集計（実施レベル = latest に 1 件以上結果があるレベル）。
    # あわせて実行主体別内訳（自動 auto / 手動 manual。classify_executed_by）を
    # latest 採用の実施ケースごとに機械集計する（report-format.md 3.2）
    level_rows = []
    executed_levels = []
    total = {"target": 0, **{s: 0 for s in STATUS_ORDER}, **{k: 0 for k in EXECUTION_CLASS_KEYS}}
    for level in LEVEL_ORDER:
        level_ids = [c.get("id") for c in active_cases if c.get("level") == level]
        executed_ids = [cid for cid in level_ids if cid in latest_detail]
        if not executed_ids:
            continue
        executed_levels.append(level)
        row = {
            "level": level,
            "target": len(level_ids),
            **{s: 0 for s in STATUS_ORDER},
            **{k: 0 for k in EXECUTION_CLASS_KEYS},
        }
        for cid in executed_ids:
            status = str(latest_detail[cid]["ref"].get("status", ""))
            if status in STATUS_ORDER:
                row[status] += 1
            row[classify_executed_by(latest_detail[cid]["result"].get("executed_by"))] += 1
        level_rows.append(row)
        total["target"] += row["target"]
        for s in STATUS_ORDER:
            total[s] += row[s]
        for k in EXECUTION_CLASS_KEYS:
            total[k] += row[k]

    # 未知レベル（LEVEL_ORDER 以外）の active ケースを集計へ合算する。従来は LEVEL_ORDER のみを
    # 走査していたため、未知レベルの fail が total へ届かず verdict から静かに脱落し（見落とされ）、
    # レベル別集計にも現れなかった。無警告除外はせず unknown 行として計上し、fail も verdict へ
    # 反映させる。実施済みケース ID は unknown_level_case_ids として未確認事項に記載させる。
    unknown_level_case_ids = []
    unknown_level_values = set()
    unknown_row = {
        "level": UNKNOWN_LEVEL_KEY,
        "target": 0,
        **{s: 0 for s in STATUS_ORDER},
        **{k: 0 for k in EXECUTION_CLASS_KEYS},
    }
    for case in active_cases:
        level = case.get("level")
        if level in LEVEL_ORDER:
            continue
        cid = case.get("id")
        unknown_row["target"] += 1
        unknown_level_values.add(str(level))
        if cid in latest_detail:
            unknown_level_case_ids.append(str(cid))
            status = str(latest_detail[cid]["ref"].get("status", ""))
            if status in STATUS_ORDER:
                unknown_row[status] += 1
            unknown_row[classify_executed_by(latest_detail[cid]["result"].get("executed_by"))] += 1
    if unknown_level_case_ids:
        # 実施済み（latest に結果がある）未知レベルケースがある場合のみ集計行として計上する
        level_rows.append(unknown_row)
        total["target"] += unknown_row["target"]
        for s in STATUS_ORDER:
            total[s] += unknown_row[s]
        for k in EXECUTION_CLASS_KEYS:
            total[k] += unknown_row[k]
        print(
            "[WARN] 既知のテストレベル（levels.py の LEVEL_ORDER）以外の level を持つ実施済みケースを"
            "集計に含めました（verdict へ反映。報告書の未確認事項に記載します）: "
            + ", ".join(sorted(unknown_level_values))
        )

    # 手動内訳（latest 採用の実施ケースを test-cases.yaml の automation で機械集計。
    # サマリのレベル別集計表直下の手動内訳注記に使用する。report-format.md 3.2）
    manual_breakdown = {"manual-assist": 0, "exploratory": 0}
    for cid in latest_detail:
        automation = str((case_by_id.get(cid) or {}).get("automation") or "")
        if automation in manual_breakdown:
            manual_breakdown[automation] += 1

    if total["fail"] > 0:
        verdict = "FAIL"
    elif total["blocked"] > 0 or total["skipped"] > 0:
        verdict = "INCOMPLETE"
    else:
        verdict = "PASS"

    # NG 一覧（latest が fail のケース）
    ng_rows = []
    for cid in sorted(latest_detail, key=sort_key):
        detail = latest_detail[cid]
        if str(detail["ref"].get("status")) != "fail":
            continue
        case = case_by_id[cid]
        result = detail["result"]
        defect = result.get("defect") or {}
        ng_rows.append(
            {
                "case_id": cid,
                "level": case.get("level", ""),
                "title": case.get("title", ""),
                "severity": defect.get("severity", ""),
                "evidence": defect.get("evidence") or result.get("evidence") or [],
                "defect": defect,
                "result": result,
            }
        )

    # 未確認事項（latest が skipped のケース）
    skipped_rows = []
    for cid in sorted(latest_detail, key=sort_key):
        detail = latest_detail[cid]
        if str(detail["ref"].get("status")) != "skipped":
            continue
        case = case_by_id[cid]
        skipped_rows.append(
            {
                "case_id": cid,
                "level": case.get("level", ""),
                "reason": detail["result"].get("reason", ""),
            }
        )

    # run 集計推移（deprecated 除外後のケースの結果のみ）
    run_rows = []
    for run in runs:
        run_id = run.get("run_id")
        counts = {s: 0 for s in STATUS_ORDER}
        for entry in results:
            if entry.get("run_id") != run_id or entry.get("case_id") not in case_by_id:
                continue
            status = str(entry.get("status", ""))
            if status in counts:
                counts[status] += 1
        run_rows.append({"run": run, "counts": counts})

    # ケース別推移（行 = 結果が 1 件以上ある active ケース、列 = run 昇順）
    matrix_ids = sorted(
        {e.get("case_id") for e in results if e.get("case_id") in case_by_id},
        key=sort_key,
    )
    matrix = []
    for cid in matrix_ids:
        statuses = []
        for run in runs:
            entry = result_index.get((cid, run.get("run_id")))
            statuses.append(str(entry.get("status", "")) if entry else "")
        matrix.append({"case_id": cid, "statuses": statuses})

    target = (
        (cases_doc.get("meta") or {}).get("target")
        or (results_doc.get("meta") or {}).get("target")
        or ""
    )
    return {
        "target": target,
        "active_cases": active_cases,
        "case_by_id": case_by_id,
        "runs": runs,
        "latest_detail": latest_detail,
        "level_rows": level_rows,
        "executed_levels": executed_levels,
        "total": total,
        "manual_breakdown": manual_breakdown,
        "verdict": verdict,
        "ng_rows": ng_rows,
        "skipped_rows": skipped_rows,
        "unknown_latest_ids": unknown_latest_ids,
        "unknown_level_case_ids": unknown_level_case_ids,
        "masked_case_ids": masked_case_ids,
        "annotations": annotations,
        "run_rows": run_rows,
        "matrix": matrix,
        "has_ng_only_run": any(r.get("mode") == "ng-only" for r in runs),
    }


# ---------------------------------------------------------------------------
# 共通整形ヘルパ
# ---------------------------------------------------------------------------


def join_lines(values):
    return "\n".join(str(v) for v in (values or []))


def date_part(value):
    return str(value)[:10] if value else ""


# defect.extras の値の表示上限文字数（stack_trace 等の長大値対策。report-format.md 3.4）
EXTRAS_VALUE_MAX_CHARS = 500


def truncate_extras_value(value):
    """defect.extras の値を表示用に切り詰める（先頭 500 文字 + 省略表記。記録値は変更しない）。"""
    text = str(value)
    if len(text) > EXTRAS_VALUE_MAX_CHARS:
        return text[:EXTRAS_VALUE_MAX_CHARS] + "…（省略）"
    return text


# extras 内 list の dict 要素（session_findings の発見事象等）の既知キーの表示ラベル
# （manual-execution.md 6.5 / yaml-schema-results.md 4 章の session_findings 規約に対応）
_EXTRAS_ENTRY_KEY_LABELS = {
    "finding": "事象",
    "reproducibility": "再現性",
    "promoted_to_defect": "defect 化",
}


def _format_extras_entry(entry):
    """extras 内 list の dict 要素 1 件を可読な 1 行へ整形する（情報欠落なし）。

    session_findings の既知キーは日本語ラベルへ置き換え、
    「事象: …（再現性: …・defect 化: 有/無）」形式にする。
    既知以外のキーもキー名のまま併記し、値を欠落させない。
    """
    parts = []
    for key, value in entry.items():
        if key == "finding":
            continue
        label = _EXTRAS_ENTRY_KEY_LABELS.get(key, str(key))
        if key == "promoted_to_defect":
            value = "有" if value else "無"
        parts.append(f"{label}: {value}")
    detail = "・".join(parts)
    if "finding" in entry:
        head = f"事象: {entry.get('finding')}"
        return f"{head}（{detail}）" if detail else head
    return detail


def format_extras_value_lines(value):
    """defect.extras の値を表示用の行リストへ整形する（表示のみ。記録値は変更しない）。

    session_findings 等の list 値を Python repr（str(list)）のまま転載すると可読性が
    低いため、要素 1 件 = 1 行へ展開する（dict 要素は _format_extras_entry で整形・
    dict 以外の要素は従来どおり文字列化）。list 以外の値・空 list は従来どおり
    文字列化した 1 行を返す。各行に truncate_extras_value の切り詰め規則を適用する。
    """
    if isinstance(value, list) and value:
        lines = []
        for entry in value:
            if isinstance(entry, dict):
                text = _format_extras_entry(entry)
                # 空 dict 等で整形結果が空になる場合は従来の文字列化へ縮退（欠落させない）
                lines.append(truncate_extras_value(text if text else entry))
            else:
                lines.append(truncate_extras_value(entry))
        return lines
    return [truncate_extras_value(value)]


def format_duration(value):
    """実行時間の表示整形。0（0.0）は「<0.01」と表示する（記録値は変更しない。report-format.md 3.4）。"""
    if value is None:
        return ""
    if isinstance(value, (int, float)) and not isinstance(value, bool) and value == 0:
        return "<0.01"
    return value


def annotation_target(entry):
    """所見・注記の「対象」列表記（case_id / run_id の併記。両方 null は「全体」）。"""
    parts = [str(p) for p in (entry.get("case_id"), entry.get("run_id")) if p]
    return " / ".join(parts) if parts else "全体"


def level_label(level):
    return LEVEL_DISPLAY_NAMES.get(level, str(level))


def manual_breakdown_note(model):
    """サマリのレベル別集計表直下に出力する手動内訳注記（両形式共通の定型文）。

    件数は latest 採用の実施ケースを test-cases.yaml の automation で機械集計した値
    （build_model の manual_breakdown）。human-assisted の結果が人間の実施・申告に
    基づく記録であることを、集計表の自動 / 手動列と対で明示する（report-format.md 3.2）。
    """
    breakdown = model["manual_breakdown"]
    return (
        f"手動内訳: manual-assist {breakdown['manual-assist']} 件 / "
        f"exploratory {breakdown['exploratory']} 件。"
        "human-assisted の結果は人間の実施・申告に基づく。"
    )


def build_disclaimer_rows(model):
    rows = []
    for name, text in DISCLAIMERS:
        if name == "再テスト" and model["has_ng_only_run"]:
            text = text + " 本報告の対象 run には ng-only 実行が含まれる。"
        rows.append((name, text))
    return rows
