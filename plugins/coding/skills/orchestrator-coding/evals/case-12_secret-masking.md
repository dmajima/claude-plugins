# Case 12: 成果物への機密情報混入 → Phase 6 マスク経路

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「バッチ処理に DB 接続の設定を追加して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | C#（ASP.NET Core）プロジェクト。Phase 2 の影響調査で既存 `appsettings.json` の接続文字列（`Server=...;User Id=...;Password=<値>` 形式の平文パスワードを含むダミー値）を `impact-analysis.md` に引用してしまい、成果物に接続文字列（パスワード込み）が残る状況 |

## 期待動作

### Phase 1〜5
- 通常どおり進行する。実装フェーズでは接続情報を環境変数 / シークレットストア経由にする方針を採るが、影響分析に引用した既存接続文字列が成果物に残存している

### Phase 6: Report（機密情報チェック）
- `references/workflow.md` Phase 6 手順 2「全成果物を Grep で走査する（`password` / `token` / `secret` / `Bearer ` / `sk-` / `AKIA` / `Server=` + パスワード様文字列 / PEM ヘッダ / メールアドレス形式）」を実施する
- `impact-analysis.md` 内の接続文字列（`Server=` + パスワード様文字列）を検出する
- 検出した該当値を `***` にマスクする（例: `Server=...;Password=***`）。フルの機密値は報告・ログに出力しない
- `implementation-report.md` を含む全成果物にフルの機密値が残らないことを確認する

### 検証
- 品質ゲート観点「機密チェックが完了したか」を満たす

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 検出 | 接続文字列内のパスワード（`Server=` + パスワード様文字列） |
| マスク後 | 該当値を `***` に置換（例: `Server=...;Password=***`） |
| 生成ファイル | 全成果物にフルの機密値が残らない |
| 終了状態 | 成功（マスク完了） |

## 分岐の根拠

このケースが分岐するトリガーは 成果物への機密情報の実混入（接続文字列）である。
`references/workflow.md` Phase 6 の機密情報チェック（Grep 走査 → `***` マスク）を検証する。既存ケースは混入なしの正常系のみで、実混入 → マスク経路が未検証だったため本ケースで補完する。

## 関連ケース

- [case-01_standard-full-workflow.md](case-01_standard-full-workflow.md)（機密混入がなくマスク不要の正常系との対比）
- `../../orchestrator-design/evals/case-06_secret-masking.md`（設計 WF の Phase 4 での同種マスク経路）
