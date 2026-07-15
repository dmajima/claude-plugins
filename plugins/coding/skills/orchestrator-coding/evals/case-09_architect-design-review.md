# Case 09: 大規模判定 → architect 設計レビュー → Phase 5 競合裁定

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「決済確定後に注文ステータスを自動更新する機能を追加して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | C#（ASP.NET Core）プロジェクト。変更見込み 6 ファイル・`PaymentModule` と `OrderModule` の 2 モジュール横断。決済という高リスク領域に該当 |

## 期待動作

### Phase 3: Design（architect レビュー分岐が焦点）
- 実装方針・変更ファイルリスト・リスクを `implementation-design.md` に記録
- design-principles.md 節 2.3 の判定基準に **該当** することを確認（「5 ファイル以上かつ複数モジュール横断」+「決済という高リスク領域」の 2 条件を満たす）
- `coding:architect` エージェントを起動し、implementation-design.md + impact-analysis.md + 適用言語スキル（coding-csharp）の references パスを渡す
- architect の High 指摘（例: 決済確定と注文更新が別トランザクションで二重書き込みとなり不整合リスク）を設計に反映（確定処理を `PaymentModule` の単一トランザクション境界へ集約する方針へ修正）し、該当箇所を再レビュー

### Phase 4: Implement
- 修正後の設計（PaymentModule への集約）に従って実装

### Phase 5: Self-Review（設計指摘と実装指摘の競合が焦点）
- `coding:impl-reviewer` + `coding:test-engineer` を並列起動
- impl-reviewer が High 指摘: 「PaymentModule への集約により `OrderModule` が `PaymentModule` の内部型に依存し依存方向が逆転している（レイヤ違反）。ドメインイベント発行で疎結合にすべき」
- これは Phase 3 で architect が確定した設計方針（整合性のための集約）と **競合** する
- 統合判断（agents.md「結果の取り込み」の裁定ルールを設計指摘 × 実装指摘へ適用）:
  1. **両論を記録**: architect の設計意図（整合性の担保）と impl-reviewer の実装指摘（依存方向の維持）を self-review-result.md に併記
  2. **メインが裁定**: design-principles.md 節 1（依存方向・境界）に照らし「整合性と依存方向は両立可能 = PaymentModule 内トランザクション + ドメインイベント発行の併用」と判断
  3. **判断根拠を記録**: 裁定根拠と、設計起因のため Phase 3 へ遡行する判断を self-review-result.md の「遡行記録」に残す
- 設計起因の調整のため **Phase 3 へ遡行**（architect 方針にイベント発行を追記、必要に応じ architect へ再諮問）→ 再実装 → 該当箇所を再レビューして PASS

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| エージェント起動 | `coding:architect`（Phase 3）1 回以上 + `coding:impl-reviewer` / `coding:test-engineer`（Phase 5 並列） |
| 生成ファイル | implementation-design.md（architect 反映済み）+ self-review-result.md（両論・裁定・根拠・遡行記録あり）、最終的に Critical / High = 0 件 |
| 終了状態 | 成功（裁定 → Phase 3 遡行 → 再レビュー PASS） |

## 分岐の根拠

このケースが分岐するトリガーは design-principles.md 節 2.3 判定 = 該当（5 ファイル以上 + 複数モジュール横断 + 高リスク領域 = 決済）である。加えて、agents.md「結果の取り込み」の裁定ルール（両論記録 + メイン裁定 + 根拠記録）を、reviewer × test だけでなく **architect の設計指摘 × impl-reviewer の実装指摘** の競合へ適用する分岐を検証する。競合が設計起因のため workflow.md 節 0.3 遡行規定（Phase 5 → Phase 3）が適用される。

## 関連ケース

- `case-01_standard-full-workflow.md`（architect 非該当・競合なしの正常系）
- `case-08_quality-gate-fail-backtrack.md`（Phase 5 → Phase 3 の設計起因遡行）
- `case-10_backtrack-phase5-to-phase4.md`（Phase 5 → Phase 4 の実装起因遡行との対比）
- orchestrator-design `case-03_large-scale-architect-review.md`（設計 WF での architect レビュー）
