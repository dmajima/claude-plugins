# case-06 fail 記録の一次バリデーション欠落 → 追加取得指示

fail の中間結果に defect 3 点セットの欠落がある場合、record（exit 2）で記録を確定させず、実行スキルへ追加取得を指示して充足後に再 record することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 状況 | Phase 5 実行中。test-run-functional から受領した中間結果 JSON のうち、TC-FUNC-002 が `status: fail` だが `defect.reproduction_steps` と `defect.evidence` を欠いている |
| 前提 | run は start-run 済み（in_progress）。他ケース（pass）の record は正常に完了している |

## 分岐の根拠

SKILL.md「実行フロー」Phase 5 手順 3（record が exit 2 を返した場合は stderr の欠落フィールドを添えて当該実行スキルへ追加取得を指示し、充足後に再 record する）、SKILL.md「results_manager.py」（exit 2 = バリデーションエラー・欠落フィールドを stderr 出力 / exit 3 = ロック競合 / exit 64 = 引数パースエラー）、プラグイン共通 references/yaml-schema.md 3.1（exit code 表）、references/evidence-policy.md 1 章（fail 時の必須 3 点セット）・2 章（一次バリデーション: 充足するまで record を確定しない・その場で実行スキルに追加取得を指示）、references/execution-policy.md 4 章（中間結果フォーマット）。

## 期待動作

- `results_manager.py record` を実行し、exit code 2 と stderr の欠落フィールド（`defect.reproduction_steps` / `defect.evidence` 等）を受け取る
- 欠落した fail を「記録済み」として扱わない（test-results.yaml に当該エントリが追記されていないことを前提に進行する）
- オーケストレータ自身が再現手順やエビデンスパスを推測・創作して JSON を補完しない
- 当該実行スキル（test-run-functional）へ、欠落フィールドを明示して**追加取得**（スクリーンショット再取得・コンソールログ収集・環境情報を含む再現手順の補完）を Skill 起動で指示する
- 追加取得後の完全な結果 JSON で record を再実行し、exit 0 を確認してから次ケースへ進む
- 3 点セットが揃わないまま finish-run・報告フェーズへ進まない（最終バリデーション validate でも fail 3 点セットが再検証される前提を維持する）
- 一連の遡行は同一 run_id 内で行う（新規 run を採番しない）

exit code の区別（exit 2 との取り違え禁止）: record が **exit 3（ロック競合）** を返した場合はエビデンス不足ではなく `.lock` の残留が原因のため、実行中の results_manager.py プロセスがないことを確認したうえで `.lock` を手動削除してから同じ JSON で再試行する。**exit 64（引数パースエラー）** はサブコマンド・オプションの typo など呼び出しコマンドの構成ミスが原因のため、コマンド自体を修正して再実行する。いずれの場合も「エビデンス不足（exit 2）」と誤解して実行スキルへ追加取得を指示しない（yaml-schema.md 3.1 の exit code 表）。

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（欠落した fail エントリは追記されず、追加取得で defect 3 点セットが充足した結果のみ results_manager.py record〔exit 0〕で追記。Edit / Write の直接編集や推測・創作による補完なし） |
| 標準出力（要約） | record exit 2 と stderr の欠落フィールドを受けて test-run-functional へ追加取得を指示した経過の報告。run 完遂後は SKILL.md「引き渡し」の正常フォーマット（run_id・レベル別集計・報告書パス・未確認事項） |
| 終了状態 | 同一 run_id（in_progress）のまま再 record（exit 0）で継続。3 点セット充足を確認してから finish-run → 報告フェーズへ進む（欠落のまま先へ進まない） |

## 関連ケース

- case-01: record が一発で exit 0 になる正常系
- case-02: 再テスト run でも同じ一次バリデーションが適用される
- case-03: MCP 喪失による skipped 記録（fail の 3 点セット要件は skipped には適用されず reason 必須のみ）
