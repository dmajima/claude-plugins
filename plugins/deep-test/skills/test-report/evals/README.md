# test-report evals

本ディレクトリは `test-report` スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | モード |
|------|-----------|------------|-------|
| 01 | case-01_excel_generation.md | 対話・Excel 選択の正常系（バリデーション通過 → 監査 → Excel 生成 → サマリ返却） | 対話 |
| 02 | case-02_markdown_generation.md | 対話・Markdown 選択の正常系（6 章構成・エビデンス相対リンク・禁止記号なし） | 対話 |
| 03 | case-03_validation_failure_abort.md | 最終バリデーション違反（fail の 3 点セット欠落 / scope 不整合）→ 生成中断・差し戻し | 対話 / 非対話共通 |
| 04 | case-04_noninteractive_markdown_default.md | 非対話起動 → 形式確認なしで Markdown 既定 | 非対話 |
| 05 | case-05_multilevel_single_file.md | 複数レベル一括報告（1 ファイル・実施レベルのみシート / セクション分け） | 対話 |
| 06 | case-06_standalone_invocation.md | 単独起動（target-slug 自己解決・形式選択とも AskUserQuestion） | 単独・対話 |
| 07 | case-07_generation_script_failure.md | 生成スクリプトの非 0 終了 → エラー提示して中断（握りつぶし・空報告書禁止） | 対話 / 非対話共通 |
| 08 | case-08_evidence_audit_failure.md | validate 通過 + evidence-auditor 監査不合格（実体欠落・マスク不備）→ 生成中断・差し戻し | 対話 / 非対話共通 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（SKILL.md「引き渡し」フォーマットへの参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## モードの軸について

本スキルの evals は「対話 / 非対話」を主軸に分岐を検証する。
対話時は形式選択（Excel / Markdown）を AskUserQuestion で行い、非対話時（`--non-interactive` 委譲）は
execution-policy.md 9 章の非対話既定値表に従い Markdown 既定で自動進行する。
バリデーション・監査による生成中断（差し戻し）はモードに関わらず同一挙動である（一段目 validate = case-03 / 二段目 evidence-auditor 監査 = case-08）。
