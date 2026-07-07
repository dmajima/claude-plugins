# add-design-html evals

`add-design-html` スキルの動作分岐ごとの期待挙動ケース集。

## ケース一覧

| ファイル | 対象分岐 |
|---------|---------|
| [case-01_interactive_css_only.md](case-01_interactive_css_only.md) | 対話モード・CSS のみの基本フロー |
| [case-02_noninteractive_full.md](case-02_noninteractive_full.md) | 非対話モード（要件全指定） |
| [case-03_contract_fail_retry.md](case-03_contract_fail_retry.md) | 契約検証 FAIL → 修正リトライ |
| [case-04_html_pair_generation.md](case-04_html_pair_generation.md) | HTML ペア生成（構造変更デザイン） |
| [case-05_dev_repo_placement.md](case-05_dev_repo_placement.md) | 開発モード配置（assets/css/） |
| [case-06_user_env_placement.md](case-06_user_env_placement.md) | 利用者モード配置（designs/css/） |
| [case-07_name_conflict.md](case-07_name_conflict.md) | 予約名の拒否 |
| [case-08_trigger_html_design.md](case-08_trigger_html_design.md) | トリガー: HTML デザイン追加の自然言語依頼 |
| [case-09_breakpoint_preservation.md](case-09_breakpoint_preservation.md) | ブレークポイント 1024px の維持（JS 契約） |
| [case-10_html_pair_fail_retry.md](case-10_html_pair_fail_retry.md) | HTML ペア検証 FAIL → 修正リトライ |
| [case-11_existing_name_conflict.md](case-11_existing_name_conflict.md) | 既存デザイン名との重複（上書き確認） |
| [case-12_env_failure_no_placement.md](case-12_env_failure_no_placement.md) | 環境起因の失敗時は配置しない |
| [case-13_default_edit_refusal.md](case-13_default_edit_refusal.md) | デフォルトデザイン直接変更の依頼への対応 |

## デモ実行スクリプト

[`demo.sh`](demo.sh) は検証スクリプトの PASS / FAIL / usage エラー判定を通しで確認する
再現スクリプト（標準ライブラリのみで動作）。実行方法はスクリプト冒頭のコメントを参照。

## 実行確認方法

```bash
# CSS 契約検証
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_css.py" <design.css>

# HTML ペア検証
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_html.py" <design.html>

# サンプル変換
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-html/convert.py" <sample.md> <out.html> --css-template <design.css>
```
