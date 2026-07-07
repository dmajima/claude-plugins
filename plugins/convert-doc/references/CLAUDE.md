# convert-doc references/

Claude エージェントが convert-doc の変換・デザイン追加作業を行う際に従う原則とナビゲーション。

## 目的と範囲

このディレクトリは convert-doc プラグイン横断の共通リソース（デザイン配置規約・実行スクリプト）を集約する。

## 原則

1. **SSOT 優先**: デザインの配置・探索・命名の正典は `design-locations.md`。各スキルの references はこれを参照し、重複記述しない
2. **スクリプトは `scripts/` に集約**: 実行可能ファイルは `references/scripts/{業務単位}/` 配下にのみ配置（extension-toolkit ADR-025 準拠）。スキル直下に `scripts/` を作らない
3. **venv はプラグイン単位**: `scripts/setup/` の共通スクリプトで `<work_dir>/.venv` に 1 つ構築し全スキルで共有（本プラグイン ADR-003 / extension-toolkit ADR-024）
4. **デフォルトデザインの SSOT**: HTML/PDF は `assets/css/template.css`、PPTX は `convert_pptx.py` の `Theme` dataclass フィールドデフォルト（テーマファイルとして二重管理しない）
5. **README.md 参照禁止**: `README.md` は人間向け資料であり、エージェント動作で参照してはならない
6. **パスポータビリティ**: `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` を使用。絶対パス・ドライブレターは禁止

## ナビゲーション

| タスク | 最初に読む | 次に読む |
|-------|----------|---------|
| デザインの配置先・探索順序を知る | `design-locations.md` | 利用側スキルの選択ルール（`../skills/convert-html/references/css-js-selection.md` / `../skills/convert-pptx/references/theme-selection.md`） |
| HTML デザイン CSS を検証する | `../skills/add-design-html/references/css-contract.md` | `scripts/add-design-html/validate_css.py` |
| PPTX テーマを検証する | `../skills/add-design-pptx/references/theme-schema.md` | `scripts/add-design-pptx/validate_theme.py` |
| venv を構築・削除する | 各スキルの `references/setup.md` | `scripts/setup/setup_venv.sh` / `teardown_venv.sh` |

## ディレクトリ構成

| パス | 種別 | 参照タイミング |
|------|------|-------------|
| `design-locations.md` | 規約（SSOT） | デザインの列挙・配置・命名時に必ず確認 |
| `scripts/setup/` | venv 共通スクリプト | 各スキルの環境構築時 |
| `scripts/convert-*/` | 変換スクリプト | 各変換スキルの実行時 |
| `scripts/add-design-*/` | デザイン検証スクリプト | デザイン追加スキルの検証時 |
