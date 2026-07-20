# test-run-integration スキル

内部結合テスト（IT-a / integration-internal / TC-ITA）と外部結合テスト（IT-b / integration-external / TC-ITB）を Playwright MCP + API 呼び出しで実施する実行スキル。
モジュール間・画面間の連携フローと外部システム・API 連携を確認し、テストケース単位の中間結果 JSON をオーケストレータへ返却する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 担当範囲

| 項目 | 内容 |
|------|------|
| テストレベル | 内部結合（`integration-internal` / `TC-ITA-*`）+ 外部結合（`integration-external` / `TC-ITB-*`） |
| 実行機構 | Playwright MCP（連携フローのブラウザ実操作）+ Bash / curl（API 補助確認） |
| IT-a の確認内容 | 画面遷移とパラメータ引き継ぎ・モジュール間のデータ受け渡し（登録値と参照値の突合）・状態遷移・エラー伝播 |
| IT-b の確認内容 | 外部 API 呼び出しと応答処理・データ形式変換・異常応答時のエラーハンドリング。接続不可時はスタブポリシー（プラグイン共通 references の test-levels.md 5 章）で判断 |
| エビデンス | 画面スクリーンショット + API レスポンス（機微情報マスク済み） |

## 使い方

### 起動経路

| 経路 | 説明 |
|------|------|
| オーケストレータ経由（標準） | `/deep-test:test` のフルフロー、または run-only / 再テストモードの run フェーズから、scope に結合レベルのケースが含まれる場合に自動委譲される（MCP ゲート通過後） |
| 単独起動 | 必須入力（target-slug / run_id / 対象ケース / 対象 URL）が揃わない場合は実行せず、オーケストレータ経由の起動を案内する |

### 入出力

| 区分 | 内容 |
|------|------|
| 入力 | target-slug / run_id / 対象ケースリスト（IT-a / IT-b 混在可）/ 対象アプリ・外部接続先情報 |
| 出力 | ケースごとの中間結果 JSON（status / reason / executed_by / duration_sec / actual / evidence / defect）。**test-results.yaml への書き込みは行わない**（記録はオーケストレータが一元実行） |

## 動作例

1. オーケストレータから TC-ITA-001（受注登録 → 一覧反映）と TC-ITB-001（外部決済 API 連携）の scope を受領
2. IT-a: 登録画面で入力 → 参照画面で表示値を取得し、登録値と参照値の突合結果を actual に記録
3. IT-b: 外部テスト用エンドポイントの疎通を確認。接続不可ならスタブポリシーに従い「スタブ実行（実接続未検証を明記）」か「skipped + reason」を判断
4. 応答内容の裏取りが必要な場合は curl で API を直接確認し、機微情報をマスクしてエビデンス保存（認証が必要な場合は credentials-manager 系スキルの利用を案内）
5. fail 時は登録側・参照側のスクリーンショット + マスク済み API レスポンスを含む defect 3 点セットを収集し、中間結果 JSON を返却

## カスタマイズ・拡張

| 拡張対象 | 方法 |
|---------|------|
| IT-a / IT-b の確認手順の拡充 | `references/integration-execution.md` 1〜2 章を更新する |
| スタブ判断基準の変更 | プラグイン共通 `references/test-levels.md` 5 章（SSOT）を改訂する（本スキル側は運用手順のみ） |
| マスキング対象の追加 | プラグイン共通 `references/evidence-policy.md` 5 章（SSOT）を改訂する |
| 利用 MCP ツールの増減 | プラグイン共通 `references/playwright-mcp.md` 5 章（正本ツールリスト）を改訂したうえで、SKILL.md frontmatter の allowed-tools へ同期する（同期義務） |
| 動作分岐の検証ケース追加 | `evals/` に `case-NN_<slug>.md` を追加し、`evals/README.md` の一覧表を更新する |

## ファイル構成

```
plugins/deep-test/skills/test-run-integration/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── references/
│   └── integration-execution.md          # IT-a/IT-b 実行・スタブ判断・API 補助確認・マスキング
└── evals/                                # 動作分岐検証ケース（case-01〜12 + README・12 ケース）
```

## スコープ外

- 結合以外のテストレベルの実行（unit / functional / system / uat / performance / security）
- test-results.yaml への書き込み・報告書生成
- Playwright MCP の登録・セットアップ（test-setup が担当）
- 認証情報の保存・解決・適用（credentials-manager 系スキルが担当。本スキルは案内のみ）
- テストケースの設計・修正、実行結果のレビュー

## 関連スキル

- `test` — オーケストレータ（MCP ゲート・run_id 採番・実績記録・フェーズ制御）
- `test-setup` — Playwright MCP の登録・検出・再起動ハンドオフ
- `test-run-unit` / `test-run-functional` / `test-run-scenario` / `test-run-performance` / `test-run-security` — 他レベルの実行スキル
- `test-review` — 実行結果のレビュー（結果文脈）
- `test-report` — 報告書生成
