# Case 04: 非対話モード（--non-interactive）での設計フロー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「監査ログ基盤の設計をして --non-interactive」 |
| 引数 | 設計依頼 |
| フラグ | `--non-interactive` |
| 既存状態 | Python（Django）プロジェクト。影響が複数モジュールに跨り（記録対象が複数サービス）、記録方式に複数の代替案が想定される。設計ゴールの細部（保持期間・記録粒度）が未指定 |

## 期待動作

### 全フェーズ共通
- `AskUserQuestion` を発火させず、不明点は **最も保守的な解釈**（デフォルト）を採用して進行
- 採用したデフォルト判断を各成果物の「確認事項と回答」欄に記録（確認方法 = デフォルト採用）
- コードは一切変更しない（設計のみ）

### Phase 1: Intake
- 未指定の設計ゴール（保持期間・記録粒度）は保守的なデフォルトを採用（例: 保持期間は既存ポリシー準拠、粒度は操作単位）し、その判断を implementation-plan.md に記録

### Phase 3: Design
- 記録方式の代替案（同期記録 / 非同期キュー経由）が拮抗した場合も **推奨案を自動採用**（評価軸: 設計観点 + リスク + 工数）し、採用理由と不採用案を implementation-design.md に記録
- design-principles.md 節 2.3 の判定基準（複数モジュール横断・個人情報を含むログという高リスク領域）に該当するため `coding:architect` を起動
- architect の Critical / High 指摘は **通常どおり反映**（非対話でも省略しない）。設計を修正し該当箇所を再レビュー

### Phase 4: Report
- design-report.md の「設計レビュー」欄に architect 実施と Critical / High 指摘への対応内容を記録
- デフォルト採用した判断・自動採用した推奨案の一覧を引き継ぎ事項として明記

### 品質ゲート FAIL で解決不能の場合
- 遡行上限（同一フェーズ 3 回）を超えても解消しない等、自動で解決不能な場合は **中断してユーザに状況を報告**（無限に自動続行しない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 0 回（AskUserQuestion 不発火） |
| エージェント起動 | `coding:architect`（節 2.3 該当のため実施） |
| 生成ファイル | implementation-plan.md / impact-analysis.md / implementation-design.md / design-report.md（いずれもデフォルト判断・推奨案採用理由・architect 対応の記録あり） |
| コード変更 | なし（0 ファイル） |
| 終了状態 | 成功 / 解決不能時は中断 + 状況報告 |

## 分岐の根拠

このケースが分岐するトリガーは フラグ = `--non-interactive` である。workflow.md Phase 3 手順 3（「非対話モードでは推奨案を採用し理由を記録」）と Phase 1 手順（不明点のデフォルト採用）が適用される。architect の Critical / High 反映は非対話でも通常どおり実施される。

## 関連ケース

- `case-01_design-only-request.md`（対話モードでは代替案を AskUserQuestion で確認）
- `case-03_large-scale-architect-review.md`（architect レビューの起動条件）
- orchestrator-coding `case-07_non-interactive.md`（実装 WF での非対話挙動との対比）
