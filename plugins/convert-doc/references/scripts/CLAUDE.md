# convert-doc references/scripts/

実行可能スクリプトの集約ディレクトリ（extension-toolkit ADR-025 準拠）。業務単位ごとにサブフォルダを切る。

## ファイル一覧

| パス | 役割 |
|------|------|
| `setup/setup_venv.sh` / `setup/teardown_venv.sh` | プラグイン共通 venv の構築 / 削除（`<work_dir>/.venv`） |
| `setup/requirements.txt` | 全スキル分の依存をマージ（バージョン固定） |
| `convert-html/convert.py` | Markdown → 自己完結 HTML 変換（`--css-template` / `--html-template` / `--js-features`） |
| `convert-pdf/convert_pdf.py` | Markdown → PDF（convert.py を subprocess 実行 + Playwright/Chromium） |
| `convert-pptx/convert_pptx.py` | Markdown → PPTX（`Theme` dataclass / `--theme` / `--dump-default-theme`） |
| `convert-pptx/run_via_job.sh` | convert_pptx.py の timeout 付き起動ラッパー（python-pptx ハング対策） |
| `convert-from-pptx/convert_from_pptx.py` | PPTX → Markdown / 構造化 JSON 抽出 |
| `convert-from-pptx/verify_md.py` | 変換カバレッジ検証 |
| `convert-from-pptx/run_via_job.sh` / `run_verify_via_job.sh` | 同上の起動ラッパー |
| `add-design-html/validate_css.py` | デザイン CSS のセレクタ契約・JS 契約検証 |
| `add-design-html/validate_html.py` | HTML テンプレートペアのプレースホルダ・骨格 DOM 検証 |
| `add-design-pptx/validate_theme.py` | テーマ JSON 検証（convert_pptx.load_theme へ委譲。composition 含む） |
| `add-design-pptx/check_default_composition.py` | theme-schema.md の既定構図リファレンスと `build_default_composition()` の同期照合 |

## 利用ルール

1. **起動は各スキルの `references/procedures.md` に従う**（venv python の明示指定・Bash ツール経由）
2. **python-pptx を使うスクリプト**（convert_pptx.py / convert_from_pptx.py）は PowerShell ツール直接起動でハングする既知事象があるため、Bash 経由または `run_via_job.sh` で起動する
3. **エンコーディング**: 全スクリプトが stdout/stderr の UTF-8 再構成とファイル I/O の encoding 明示を実装済み。改修時も維持する
4. **静的解析**: `../ruff.toml`（references/ 直下）が全スクリプトに適用される
5. **パス解決**: `CLAUDE_PLUGIN_ROOT` 環境変数を優先し、無ければ `__file__` 相対で解決する（convert.py / convert_pdf.py）。スクリプト位置を移動する場合は解決ロジックを併せて更新する
