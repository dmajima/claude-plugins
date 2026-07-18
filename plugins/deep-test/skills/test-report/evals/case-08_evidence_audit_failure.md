# case-08 validate 通過後の evidence-auditor 監査不合格 → 生成中断・差し戻し

results_manager.py の validate は通過するが、evidence-auditor の監査でエビデンスファイルの実体欠落・マスク不備が検出されるケース。validate とは**別観点**の監査として生成を中断し差し戻すことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動 | オーケストレータ `test` から委譲（対話 / 非対話いずれでも同一挙動） |
| 前提 | validate は通過する（fail の defect 3 点セットは YAML 上すべて記録済み・scope/results 突合も一致）。しかし（1）fail 1 件の `defect.evidence` に記録されたパスの実体ファイルが `evidence/{run_id}/{case_id}/` に存在せず、（2）別の fail 1 件のテキストログ（evidence 実体）にマスクされていない認証情報（Bearer トークン）が残っている |

## 分岐の根拠

SKILL.md「責務」2（生成前に validate〔3 点セット・scope/results 突合〕と evidence-auditor 監査〔エビデンス実在・マスキング状態〕を通す = 二段バリデーションの最終段）・「実行フロー」ステップ 3（evidence-auditor 監査で欠落・未マスクの高信頼指摘があれば生成を中断して差し戻す）・「引き渡し」差し戻しフォーマット（中断理由: エビデンス監査指摘）・「重要な制約」（監査で未マスクを検出したまま生成しない）、`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 1 章（evidence-auditor は test-report が単独起動）・4.2（追加入力: fail 全件の defect 詳細・evidence/ 配下の実ファイルパス一覧・validate の結果）・4.3（共通注入事項）・5 章（監査結果を最終バリデーションの判定材料とし、欠落検出時は生成を中断して差し戻す）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（evidence は実在するファイルであること）・5 章（機微情報マスキング: 報告書への転載時は必須マスク）。

## 期待動作

- results_manager.py の `validate` を実行し、通過（violations 0 件）を確認してステップ 3（監査）へ進む
- evidence-auditor を Agent ツールで単独起動する（`subagent_type: "deep-test:evidence-auditor"`。共通注入事項ブロックと、fail 全件の defect 詳細・evidence/ 実ファイルパス一覧・validate 結果を含める。agents.md 4 章）
- 監査で（1）エビデンス実体の欠落（YAML に記録されたパスに対応するファイルの不在）、（2）未マスクの認証情報の残存、を高信頼の指摘として受領する
- **validate 通過を理由に生成へ進まない**: validate は実績 YAML 上の記録内容（3 点セットの記録有無・scope/results 突合）の検証、evidence-auditor はエビデンスファイルの実在とマスキング状態というファイル実体側の監査であり、**観点が異なる**。両方を通過するまで生成しない旨を差し戻しに明記する
- 形式選択（AskUserQuestion / Markdown 既定）・生成スクリプト（generate_excel.py / generate_markdown.py）へ進まず**生成を中断**する
- SKILL.md「引き渡し」の差し戻しフォーマットで返却する: 中断理由（エビデンス監査指摘）・違反一覧（ケース ID / 欠落ファイルパス・未マスク箇所）・必要な対応（エビデンス追加取得・record 補完・マスキング適用 等）
- 差し戻しのために test-results.yaml・エビデンスファイルを自分で修正しない（マスク適用・record 補完は本スキルの責務外。書き込みはオーケストレータ・実行スキル側）
- 未実施・欠落を「問題なし」と書き換えない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（生成スクリプトを実行しない。test-results.yaml・エビデンスも修正しない） |
| 標準出力（要約） | SKILL.md「引き渡し」差し戻しフォーマット（中断理由〔エビデンス監査指摘。validate は通過済みで観点が異なる旨を明記〕・違反一覧〔ケース ID / 実体欠落パス・未マスク箇所〕・必要な対応） |
| 終了状態 | 生成中断（差し戻し）。validate 通過・監査不合格という二段目のみの不合格として返却 |

## 関連ケース

- case-03: 一段目（validate）の違反による生成中断（本ケースは validate 通過後の二段目で中断する側）
- case-01 / case-02: validate・監査とも通過する正常系
