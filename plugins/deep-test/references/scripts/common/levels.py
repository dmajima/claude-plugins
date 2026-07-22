#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""deep-test 共通レベル定数モジュール（テストレベル定数のコード上の SSOT）。

テストレベルに関する定数（正準順序・ケース ID プレフィクス対応・表示名・用語注記）を一元管理し、
results_manager.py（skills/test/references/scripts/results/）と
report_model.py（skills/test-report/references/scripts/report/）が共有する。
両スクリプトはそれぞれ sys.path にこの common ディレクトリを追加して本モジュールを import する。

【同期義務】
本モジュールはテストレベル定数の **コード上の SSOT** である。
散文の SSOT は references/test-levels.md（レベル定義・入口/出口基準・ケース ID プレフィクス表・
ユニット / 単体の用語注記）である。レベルの追加・改名・表示名変更・用語注記変更を行う場合は、
必ず本モジュール（コード SSOT）と test-levels.md（散文 SSOT）の **両方** を同時に更新すること。

本モジュールは定数定義のみを行い、import 時に stdout / stderr へ出力しない
（標準出力・標準エラーの UTF-8 再構成は import 元の各エントリスクリプトが実施する）。
"""

import re

# レベルの正準順序（報告書のシート順・集計順・ソートキーに用いる）。
LEVEL_ORDER = (
    "unit",
    "functional",
    "integration-internal",
    "integration-external",
    "system",
    "uat",
    "performance",
    "security",
)

# ケース ID プレフィクストークン → level 値（TC-UNIT → unit 等）。挿入順は LEVEL_ORDER に対応させる。
ID_PREFIX_TO_LEVEL = {
    "UNIT": "unit",
    "FUNC": "functional",
    "ITA": "integration-internal",
    "ITB": "integration-external",
    "SYS": "system",
    "UAT": "uat",
    "PERF": "performance",
    "SEC": "security",
}

# ケース ID の書式検証パターン（TC-{プレフィクス}-{3 桁以上連番}）。
# プレフィクス集合は ID_PREFIX_TO_LEVEL のキーから動的生成し、定義の二重管理を避ける。
_CASE_ID_PREFIX_ALT = "|".join(re.escape(prefix) for prefix in ID_PREFIX_TO_LEVEL)
CASE_ID_PATTERN = re.compile(r"^TC-(" + _CASE_ID_PREFIX_ALT + r")-\d{3,}$")

# 報告書のレベル別シート / セクションの日本語表示名（report-format.md 3.1）。
LEVEL_DISPLAY_NAMES = {
    "unit": "ユニット",
    "functional": "単体",
    "integration-internal": "内部結合",
    "integration-external": "外部結合",
    "system": "システム",
    "uat": "受入(UAT)",
    "performance": "性能",
    "security": "セキュリティ",
}

# ユニット / 単体の誤読防止の用語注記（report-format.md 3.4 / 4 章）。他レベルには不要。
LEVEL_TERM_NOTES = {
    "unit": (
        "注記: 『ユニットテスト』はコードレベルの自動テスト（テストフレームワーク実行）を指す"
        "（本プラグイン独自の区分）。"
    ),
    "functional": (
        "注記: 『単体テスト』は実アプリの画面・機能単位テスト（Playwright 実行）を指す"
        "（本プラグイン独自の区分）。"
    ),
}
