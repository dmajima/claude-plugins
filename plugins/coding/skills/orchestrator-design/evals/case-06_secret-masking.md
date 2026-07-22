# Case 06: 設計成果物への機密情報混入 → Phase 4 マスク経路

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「新しいマイクロサービスの DB 接続構成を設計して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | 設計対象の構成例として、Phase 3 の `implementation-design.md` に接続文字列（`Server=...;User Id=...;Password=<値>` 形式の平文パスワードを含むダミー値）を記載してしまい、成果物に機密が残る状況 |

## 期待動作

### Phase 1〜3
- 通常どおり設計を進める。設計方針としては接続情報を環境変数 / シークレットストア経由にすることを推奨するが、構成例に記した接続文字列が `implementation-design.md` に残存している

### Phase 4: Report（機密情報チェック）
- `references/workflow.md` Phase 4 手順 2「全成果物を Grep で走査し（`password` / `token` / `secret` / `Bearer ` / `sk-` / `AKIA` / PEM ヘッダ等）、検出時は `***` にマスクする」を実施する
- `implementation-design.md` 内の接続文字列（`Password=` = `password` パターンに一致）を検出する
- 検出した該当値を `***` にマスクする（例: `Server=...;Password=***`）。フルの機密値は報告・ログに出力しない
- `design-report.md` を含む全成果物にフルの機密値が残らないことを確認する

### 検証
- 品質ゲート観点「機密チェックが完了したか」を満たす

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 検出 | 接続文字列内のパスワード（`password` パターン一致） |
| マスク後 | 該当値を `***` に置換（例: `Server=...;Password=***`） |
| 生成ファイル | 全成果物にフルの機密値が残らない |
| 終了状態 | 成功（マスク完了） |

## 分岐の根拠

このケースが分岐するトリガーは 設計成果物への機密情報の実混入（接続文字列）である。
`references/workflow.md` Phase 4 の機密情報チェック（Grep 走査 → `***` マスク）を検証する。既存ケースは混入なしの正常系のみで、実混入 → マスク経路が未検証だったため本ケースで補完する。

## 関連ケース

- [case-01_design-only-request.md](case-01_design-only-request.md)（機密混入がなくマスク不要の正常系との対比）
- `../../orchestrator-coding/evals/case-12_secret-masking.md`（実装 WF の Phase 6 での同種マスク経路）
