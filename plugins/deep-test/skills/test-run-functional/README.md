# test-run-functional スキル

単体テスト（level: functional / TC-FUNC）を Playwright MCP によるブラウザ実操作で実施する実行スキル。
実アプリケーションの画面・機能単位の動作をユーザー操作レベルで確認し、ステップごとのスクリーンショットをエビデンスとして収集して、テストケース単位の中間結果 JSON をオーケストレータへ返却する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 導入手順

本スキル `test-run-functional` は `deep-test` プラグインに同梱されており、**追加インストールは不要**です。プラグインの導入手順（マーケットプレイス登録・インストール・自動更新の設定）は [`deep-test` プラグインの README](../../README.md) を参照してください。

- **起動トリガー**: オーケストレータ `test` の run フェーズから scope に functional レベルのケースが含まれる場合に自動委譲される（MCP ゲート通過後）。必須入力（target-slug／run_id／対象ケース／対象 URL）が揃わない直接依頼時は実行せずオーケストレータ経由を案内する

## 担当範囲

| 項目 | 内容 |
|------|------|
| テストレベル | 単体テスト（`level: functional` / ケース ID `TC-FUNC-*`）。実アプリの画面・機能単位のブラックボックステスト |
| 実行機構 | Playwright MCP（ヘッドレスブラウザ実操作） |
| 主な確認内容 | 画面表示・入力バリデーション・操作応答・メッセージ表示・単機能の正常系/異常系 |
| エビデンス | ステップごとのスクリーンショット + 失敗時のアクセシビリティスナップショット・コンソールログ |

## 使い方

### 起動経路

| 経路 | 説明 |
|------|------|
| オーケストレータ経由（標準） | `/deep-test:test` のフルフロー、または run-only / 再テストモードの run フェーズから、scope に functional レベルのケースが含まれる場合に自動委譲される（MCP ゲート通過後） |
| 単独起動 | 必須入力（target-slug / run_id / 対象ケース / 対象 URL）が揃わない場合は実行せず、オーケストレータ経由の起動を案内する |

### 入出力

| 区分 | 内容 |
|------|------|
| 入力 | target-slug / run_id / 対象ケースリスト（functional レベル）/ 対象アプリ情報（URL 等） |
| 出力 | ケースごとの中間結果 JSON（status / reason / executed_by / duration_sec / actual / evidence / defect）。**test-results.yaml への書き込みは行わない**（記録はオーケストレータが一元実行） |

## 動作例

1. オーケストレータから TC-FUNC-001（ログイン成功）等の scope と対象 URL を受領
2. MCP ツールの利用可否を確認（二重防御）し、対象 URL へ遷移
3. steps を Playwright 操作（snapshot で ref 取得 → click / type）に対応付けて実行し、各ステップ後にスクリーンショット（`{case_id}_{NN}_{label}.png`）を取得 → 直後に `evidence/{run_id}/{case_id}/` へ移送
4. expected をアクセシビリティスナップショットの表示テキスト・URL 遷移で照合
5. 不一致（fail）なら失敗時点のスクリーンショット・コンソールログ・操作列から組み立てた再現手順を収集
6. postconditions（データ復元・ログアウト）を実行し、中間結果 JSON を返却

MCP ツールが利用できない場合は、実行を偽装せず scope 全ケースを skipped + reason で返却する。

## カスタマイズ・拡張

| 拡張対象 | 方法 |
|---------|------|
| steps の対応表の拡充 | `references/functional-execution.md` 1.2 の対応表に行を追加する |
| 照合手段の追加 | `references/functional-execution.md` 2 章を更新する |
| 利用 MCP ツールの増減 | プラグイン共通 `references/playwright-mcp.md` 5 章（正本ツールリスト）を改訂したうえで、SKILL.md frontmatter の allowed-tools へ同期する（同期義務） |
| 動作分岐の検証ケース追加 | `evals/` に `case-NN_<slug>.md` を追加し、`evals/README.md` の一覧表を更新する |

## ファイル構成

```
plugins/deep-test/skills/test-run-functional/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── references/
│   └── functional-execution.md           # steps→Playwright 対応・照合方法・エビデンス手順
└── evals/                                # 動作分岐検証ケース（case-01〜14 + README・14 ケース）
```

## スコープ外

- functional 以外のテストレベルの実行（unit / integration / system / uat / performance / security）
- test-results.yaml への書き込み・報告書生成
- Playwright MCP の登録・セットアップ（test-setup が担当）
- テストケースの設計・修正、実行結果のレビュー

## 関連スキル

- `test` — オーケストレータ（MCP ゲート・run_id 採番・実績記録・フェーズ制御）
- `test-setup` — Playwright MCP の登録・検出・再起動ハンドオフ
- `test-run-unit` / `test-run-integration` / `test-run-scenario` / `test-run-performance` / `test-run-security` — 他レベルの実行スキル
- `test-review` — 実行結果のレビュー（結果文脈）
- `test-report` — 報告書生成
