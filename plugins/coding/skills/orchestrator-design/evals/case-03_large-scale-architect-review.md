# Case 03: 大規模・高リスク判定 → architect レビュー実施

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「認証基盤をセッション方式からトークン方式へ移行する設計をして」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | C#（ASP.NET Core）プロジェクト。影響が複数モジュールに跨り、認証という高リスク領域に該当 |

## 期待動作

### Phase 3: Design（レビュー分岐が焦点）
- SSOT design-principles.md 節 2.3 の判定基準（複数モジュール横断 / 高リスク領域 = 認証）に該当することを確認
- `coding:architect` エージェントを起動し、設計書（implementation-design.md）+ 影響分析 + 適用言語スキル（coding-csharp）の references パスを渡す
- architect の指摘（Critical / High）を設計に反映し、該当箇所を再レビュー
- リスク欄に互換性（既存セッションの移行）・セキュリティ（トークン失効・保存方式）の対応方針を記録

### Phase 4: Report
- design-report.md の「設計レビュー」欄に architect 実施と反映内容を記録

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| エージェント起動 | `coding:architect` 1 回以上 |
| 生成ファイル | implementation-design.md（レビュー反映済み）+ design-report.md |
| 終了状態 | 成功（レビュー指摘 Critical / High = 0 件） |

## 分岐の根拠

このケースが分岐するトリガーは design-principles.md 節 2.3 判定 = 該当（複数モジュール横断 + 高リスク領域）である。

## 関連ケース

- `case-01_design-only-request.md`（小規模で architect 非該当の場合）
