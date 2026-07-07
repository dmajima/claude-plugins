# add-design-pptx evals

`add-design-pptx` スキルの動作分岐ごとの期待挙動ケース集。

## ケース一覧

| ファイル | 対象分岐 |
|---------|---------|
| [case-01_interactive_basic.md](case-01_interactive_basic.md) | 対話モードの基本フロー（生成→検証→サンプル変換→配置） |
| [case-02_noninteractive_full.md](case-02_noninteractive_full.md) | 非対話モード（要件全指定） |
| [case-03_schema_error_retry.md](case-03_schema_error_retry.md) | スキーマ検証 FAIL → 修正リトライ |
| [case-04_dev_repo_placement.md](case-04_dev_repo_placement.md) | 開発モード配置（assets/pptx-themes/） |
| [case-05_user_env_placement.md](case-05_user_env_placement.md) | 利用者モード配置（designs/pptx-themes/） |
| [case-06_name_conflict.md](case-06_name_conflict.md) | 予約名の拒否 |
| [case-07_trigger_pptx_design.md](case-07_trigger_pptx_design.md) | トリガー: PPTX デザイン追加の自然言語依頼 |
| [case-08_dark_theme_contrast.md](case-08_dark_theme_contrast.md) | ダーク系テーマのコントラスト調整 |
| [case-09_layout_overflow_warning.md](case-09_layout_overflow_warning.md) | layout_in 過大値によるレイアウト崩れの検知 |
| [case-10_existing_name_conflict.md](case-10_existing_name_conflict.md) | 既存テーマ名との重複（上書き確認） |
| [case-11_env_failure_no_placement.md](case-11_env_failure_no_placement.md) | 環境起因の失敗時は配置しない |
| [case-12_default_edit_refusal.md](case-12_default_edit_refusal.md) | デフォルトデザイン直接変更の依頼への対応 |
| [case-13_composition_theme.md](case-13_composition_theme.md) | composition（構図）付きテーマ作成の正常系 |
| [case-14_composition_schema_errors.md](case-14_composition_schema_errors.md) | composition のスキーマ検証 FAIL → 修正リトライ |
| [case-15_composition_warnings.md](case-15_composition_warnings.md) | composition の変換時警告（title_band_height 併記 / "sym" 負値解決） |

case-13 のみ「検証観点（機械確認可能）」節を持つ。構図には独立した機械照合スクリプト
（`check_default_composition.py`）があり、期待挙動をコマンドで再確認できるため
（他ケースへの遡及追加はしない）。composition 系の自動チェックは `demo.sh` の
セクション 4・5 に組込済み（同期照合・検証・変換・round-trip・エラー/警告）。

## デモ実行スクリプト

[`demo.sh`](demo.sh) はテーマ検証の PASS / FAIL / usage エラー、`--dump-default-theme` を
種にした新テーマ作成 → サンプル変換、composition（構図）の同期照合・検証・変換・
round-trip・エラー/警告系を通しで確認する再現スクリプト。
実行方法はスクリプト冒頭のコメントを参照。

## 実行確認方法

```bash
# テーマ検証
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-pptx/validate_theme.py" <theme.json>

# サンプル変換
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" <sample.md> <out.pptx> --theme <theme.json>
```
