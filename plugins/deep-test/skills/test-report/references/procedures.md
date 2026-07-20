# 生成スクリプト実行手順（test-report）

> 環境構築（venv・依存パッケージ）は先に [setup.md](setup.md) を参照して完了させること。

報告書のフォーマット（シート構成・章立て・列定義・スタイル・免責注記）の SSOT は
`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` であり、本ファイルには複製しない。
本ファイルはスクリプトの**起動方法**のみを定める。

## 1. スクリプトと引数

| スクリプト | 出力 |
|-----------|------|
| `${CLAUDE_SKILL_DIR}/references/scripts/report/generate_excel.py` | Excel 報告書（.xlsx 1 ファイル） |
| `${CLAUDE_SKILL_DIR}/references/scripts/report/generate_markdown.py` | Markdown 報告書（.md 1 ファイル） |
| `${CLAUDE_SKILL_DIR}/references/scripts/report/report_model.py` | 共通データモデルモジュール（両スクリプトが import。**直接実行しない**。移動時は 3 ファイルを同ディレクトリに保つ） |

引数体系は両スクリプト共通:

| 引数 | 必須 | 内容 |
|------|------|------|
| `--results` | 必須 | `{target-slug}/test-results.yaml` のパス |
| `--cases` | 必須 | `{target-slug}/test-cases.yaml` のパス |
| `--output` | 必須 | 出力ファイルパス（`test-report_{target-slug}_{yyyyMMdd}.xlsx|.md`。出力先はセッション作業領域直下） |

## 2. 実行例（Bash ツール経由・venv Python 明示指定）

```bash
SESSION_DIR=".claude/.local/work/{yyyyMMdd_nn_summary}"
VENV_PY="$SESSION_DIR/workspace/.venv/Scripts/python.exe"   # Unix は .venv/bin/python
TARGET_DIR=".claude/.local/plugins/deep-test/{target-slug}"

# Excel
"$VENV_PY" "${CLAUDE_SKILL_DIR}/references/scripts/report/generate_excel.py" \
  --results "$TARGET_DIR/test-results.yaml" \
  --cases "$TARGET_DIR/test-cases.yaml" \
  --output "$SESSION_DIR/test-report_{target-slug}_{yyyyMMdd}.xlsx"

# Markdown
"$VENV_PY" "${CLAUDE_SKILL_DIR}/references/scripts/report/generate_markdown.py" \
  --results "$TARGET_DIR/test-results.yaml" \
  --cases "$TARGET_DIR/test-cases.yaml" \
  --output "$SESSION_DIR/test-report_{target-slug}_{yyyyMMdd}.md"
```

- `{target-slug}` ディレクトリの基準は `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` の解決フローに従う
- 終了コード 0 で成功。標準出力に出力パス・シート / 章構成・総合判定・集計値・NG 件数が表示される。**返却サマリにはこの出力値をそのまま転記する**（LLM の手計算禁止）
- 同名ファイルは上書きしてよい（報告書は実績 YAML から何度でも再生成できる派生物）

## 3. 起動方式の実測記録（Windows ハング既知事象の確認）

python-pptx 等では PowerShell ツール直接起動でハングする既知事象があるが、
openpyxl は純 Python のため対象外と設計されている。実装時に以下を実測確認した。

| 項目 | 結果 |
|------|------|
| 実測日 | 2026-07-17 |
| 実行方法 | Bash ツールから venv Python を直接起動（Start-Job ラッパーなし） |
| 環境 | Windows 11 / Python 3.x venv / PyYAML 6.0.3 / openpyxl 3.1.5 |
| generate_excel.py | 約 0.36 秒で正常終了（8 ケース・2 run・7 シートのテストデータ）。ハングなし |
| generate_markdown.py | 約 0.11 秒で正常終了。ハングなし |

結論: **Bash ツール経由の直接起動でよい**（Start-Job ラッパー不要）。
PowerShell ツールから起動する場合はコンソールエンコーディングの必須プリフィクスを付与すること。

補足（タイムアウト付き実行ラッパーの位置付け）: Bash 直接起動で問題ないことを実測済みのため必須ではないが、
長時間実行や PowerShell 強制運用環境ではタイムアウト付き実行の選択肢として
`${CLAUDE_PLUGIN_ROOT}/references/scripts/run/run_via_job.sh` を利用できる
（`run_via_job.sh <venv-python> <script.py> [args...]`。タイムアウト秒は環境変数 `RUN_VIA_JOB_TIMEOUT`、既定 300 秒）。

## 4. トラブルシュート

| 症状 | 確認・対処 |
|------|-----------|
| `[ERROR] ... が見つかりません` | `--results` / `--cases` のパスと target-slug の解決結果を確認する |
| `[ERROR] test-results.yaml に run がありません` | 実行実績が未記録。report フェーズより前の run フェーズが完了しているか確認する |
| `ModuleNotFoundError: yaml / openpyxl` | venv 未構築またはシステム Python を誤って使用。[setup.md](setup.md) の手順で venv を構築し、venv Python を明示指定する |
| 日本語が文字化けする | スクリプトは stdout/stderr の UTF-8 再構成実装済み。呼び出し側のエンコーディング設定（PowerShell ツール時のプリフィクス）を確認する |
| `[WARN] 禁止記号（U+00A7）を N 箇所で置換` | 入力 YAML に禁止記号が含まれている。報告書には代替表現で出力済みだが、実績記録側の記載も見直す |
| 30 秒以上出力が 0 byte のまま固まる | 本スクリプトでは未再現（3 章の実測）。再現した場合は `${CLAUDE_PLUGIN_ROOT}/references/scripts/run/run_via_job.sh`（タイムアウト付き実行）または Start-Job 経由ラッパーでの起動へ切替えて切り分ける |
| `ModuleNotFoundError: report_model` | 生成スクリプトと `report_model.py` が同ディレクトリにない。3 ファイルを `references/scripts/report/` に揃えて配置する |
