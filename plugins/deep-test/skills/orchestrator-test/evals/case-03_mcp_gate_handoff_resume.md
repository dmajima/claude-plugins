# case-03 MCP 未ロード → 再起動ハンドオフ → resume 復帰

MCP ゲートでの未ロード検知時に「利用可を装った続行」をせず停止し、再起動後の resume で同一 run_id の残ケースから継続することを検証する。

## 入力

### 前半（停止まで）

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「このアプリをテストして」 |
| 前提 | 設計・設計レビューは PASS 済み。scope に functional / system レベルを含む。Playwright MCP は**現セッションで未ロード**（test-setup が新規登録を実施） |

### 後半（再起動後）

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「resume」（または `/deep-test:test resume`） |
| 前提 | 再起動済みで MCP はロード済み。前半で unit レベル 2 件のみ record 済み・run は in_progress または interrupted のまま |

## 分岐の根拠

SKILL.md「実行フロー」Phase 4 の MCP ゲート（未ロード → 再起動ハンドオフを出力して停止）、references/flow.md 3 章（MCP ゲート判定手順: ToolSearch）・5 章（resume の途中復帰位置判定・run_id 新規採番禁止）、プラグイン共通 references/execution-policy.md 1.4（MCP ゲート・unit のみは通過）、references/playwright-mcp.md 3 章（再起動ハンドオフの 3 点）・4 章（実利用可否判定）、references/retest-policy.md 6 章（resume 規約）。

## 期待動作

### 前半（停止まで）

- MCP ゲートで ToolSearch により `mcp__playwright__*` の実利用可否を確認し、未ロードを検知する
- MCP が使えるかのように装ってブラウザ操作を続行しない。また Playwright 必要ケースを勝手に skipped で埋めて完走させない（run 前の未ロードはハンドオフが正。run 中の喪失時のみ skipped 記録）
- 再起動ハンドオフとして（1）状態保存済みの明示（test-cases.yaml / test-results.yaml は永続化済み）、（2）再起動が必要な理由の短い説明、（3）再起動後に `resume` で継続できることの 3 点を出力して**停止**する
- unit のみを先行実行した場合は、その record 済み結果が test-results.yaml に残っている（破棄しない）

### 後半（resume）

- Phase 0（target-slug 解決）を省略せずに実施したうえで、summary の `runs[]` から in_progress / interrupted の最新 run を特定する
- **run_id を新規採番せず**（start-run を実行しない）、当該 run の scope から記録済みケースを除いた残ケースのみを実行スキルへ委譲する
- 実行前に MCP ゲートを再判定する（ロード済みなら通過）
- 残ケースの record 完了後に `finish-run` で completed に確定し、Phase 6（結果レビュー）→ Phase 7（報告）へ進む
- 中断 run が複数ある場合は最新の 1 件のみを再開し、古い run はユーザー確認のうえ `finish-run --status aborted` で整理する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 前半は test-cases.yaml / test-results.yaml の永続化まで（unit 先行実行分の record は test-results.yaml に残存・報告書は生成しない）。後半は results_manager.py の record / finish-run で test-results.yaml を更新（Edit / Write の直接編集なし）し、報告書を生成 |
| 標準出力（要約） | 前半は再起動ハンドオフ 3 点（状態保存済みの明示・再起動が必要な理由・resume での継続手順）。後半は resume 完了後に SKILL.md「引き渡し」の正常フォーマット（run_id・レベル別集計・報告書パス・未確認事項） |
| 終了状態 | 前半は MCP ゲートで停止（再起動待ち。run は in_progress / interrupted のまま）。後半は run_id を新規採番せず同一 run を finish-run で completed に確定し Phase 7 まで完了 |

## 関連ケース

- case-01: MCP ロード済みでゲートを通過する正常系
- case-05: 非対話でも MCP 未ロード時は自動続行せずハンドオフ停止する（既定値表）
