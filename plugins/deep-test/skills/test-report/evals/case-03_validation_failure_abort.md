# case-03 バリデーション違反 → 生成中断・差し戻し

fail の defect 3 点セット欠落（例: test_data 未記録）や run の scope/results 不整合がある実績に対して、
報告書を生成せずに違反一覧を返却して差し戻すことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動 | オーケストレータ `test` から委譲（対話 / 非対話いずれでも同一挙動） |
| 前提 | test-results.yaml に、defect の `test_data` が欠落した fail、または scope に含まれるが results 未記録のケースを持つ run が存在する |

## 分岐の根拠

SKILL.md「実行フロー」ステップ 2（違反あり → 生成せず差し戻し）・「引き渡し」差し戻しフォーマット・「重要な制約」（未通過での生成禁止）、
`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（3 点セット必須）・2 章（最終バリデーション: 欠落 → 生成中断・差し戻し）、
`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` 1 章（事前検証未通過での生成は禁止）。

## 期待動作

- results_manager.py の `validate` を実行し、違反（欠落項目・不整合ケース）を検出する
- **generate_excel.py / generate_markdown.py を実行しない**（形式選択の AskUserQuestion にも進まない）
- 「未実施・欠落を問題なし」と書き換えず、SKILL.md「引き渡し」の差し戻しフォーマットで返却する:
  - 中断理由（最終バリデーション違反）
  - 違反一覧（ケース ID / 欠落項目・不整合の内容）
  - 必要な対応（エビデンス追加取得・record 補完等）
- 差し戻しのために test-results.yaml を自分で修正しない（書き込みはオーケストレータの責務。SKILL.md「責務外」）
- validate 自体が実行不能（results_manager.py 不在・エラー終了）の場合も生成に進まず、前提不成立として中断・報告する（SKILL.md「検証」）
- evidence-auditor 監査（ステップ 3）で欠落・未マスクの高信頼指摘が出た場合も同様に生成を中断して差し戻す

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（生成スクリプトを実行しない。test-results.yaml も修正しない） |
| 標準出力（要約） | SKILL.md「引き渡し」差し戻しフォーマット（中断理由〔最終バリデーション違反〕・違反一覧〔ケース ID / 欠落・不整合内容〕・必要な対応） |
| 終了状態 | 生成中断（差し戻し） |

## 関連ケース

- case-01 / case-02: バリデーション通過時の正常系（本ケースの対分岐）
- case-08: validate 通過後に evidence-auditor 監査（実在確認・マスキング）で不合格となる側（別観点の二段目）
