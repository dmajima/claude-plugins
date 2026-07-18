# test-setup スキル

deep-test プラグインのテスト実行環境（Playwright MCP・テストランナー・venv）を構築・検証するフェーズスキル。
チェック結果を環境検証レポートとして返却し、オーケストレータの MCP ゲート判定や実行スキルへの引き継ぎ材料を提供する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 何をするか

| チェック項目 | 内容 |
|-------------|------|
| Playwright MCP 登録 | `claude mcp list` で既存登録を検出。未登録なら規約コマンド（ローカルスコープ・ヘッドレス・出力先固定・SSL エラー無視）で新規登録 |
| Playwright MCP ロード | ToolSearch で `mcp__playwright__*` ツールの実利用可否を判定（登録の有無だけでは判定しない） |
| テストランナー | pyproject.toml / package.json / *.csproj 等から pytest / jest / vitest / dotnet test 等を検出（検出のみ・実行しない） |
| venv | セッション作業領域 `workspace/.venv` の確認。無ければオーケストレータ `test` の setup スクリプトで構築 |

MCP を新規登録した場合や、登録済みでも現セッションで未ロードの場合は、**再起動ハンドオフ**（状態保存の確認・再起動依頼・再開手順）を出力して停止します。MCP ツールは Claude Code の起動時にのみロードされるためです。

## 使い方

### トリガーフレーズ例

```
テスト環境を準備して
Playwright MCP をセットアップして
テストランナーを検出して
```

### 起動経路

| 経路 | 説明 |
|------|------|
| test オーケストレータ経由 | フルフローの setup フェーズとして Skill ツール経由で委譲される |
| 単独起動 | 上記トリガーフレーズで本スキルのみを直接実行する |

### 引数（任意）

| 引数 | 内容 |
|------|------|
| `levels=unit,functional` | 予定テストレベル。unit のみなら Playwright MCP チェックを省略する等の導出に使用 |
| `checks=playwright,runner,venv` | チェック対象の明示指定 |
| `project=<パス>` | ランナー検出の対象プロジェクトルート |
| `session=<パス>` | セッション作業領域（venv 配置先の親） |
| `--non-interactive` | 非対話モード |

## 動作例

### 例 1: 未登録環境での初回セットアップ

入力: 「テスト環境を準備して」

1. `claude mcp list` で playwright 系登録なしを確認
2. 規約コマンドで新規登録
3. ランナー検出・venv 構築も完了させる
4. 総合判定 `RESTART_REQUIRED` のレポート + 再起動ハンドオフを出力して停止

### 例 2: 登録・ロード済み環境

入力: オーケストレータから `levels=functional,system` で委譲

1. 既存登録を検出（重複登録しない）
2. ToolSearch でロード済みを確認
3. venv 確認（unit を含まないためランナー検出は対象外・not-checked）
4. 総合判定 `READY` のレポートを返却

## 出力

`SKILL.md` の「引き渡し」に定義された環境検証レポート（総合判定 READY / RESTART_REQUIRED / PARTIAL + チェック項目表 + 引き継ぎ事項）。

## ファイル構成

```
plugins/deep-test/skills/test-setup/
├── SKILL.md                          # Claude が実行時に読むスキル定義
├── README.md                         # 本ファイル（人間向け）
├── references/
│   └── setup-procedures.md           # 検出・登録・判定・ハンドオフの詳細手順
└── evals/                            # 動作分岐検証ケース（case-01〜05 + README）
```

## スコープ外

- テストの実行（`test-run-*` 実行スキルが担当）
- MCP ゲートの判定そのもの（オーケストレータ `test` が担当。本スキルは判定材料の提供まで）
- テスト計画・ケース設計（`test-design`）、成果物レビュー（`test-review`）

## 関連スキル

- `test` — オーケストレータ（ライフサイクル制御・ゲート判定）
- `test-run-unit` — 検出したテストランナーを実際に実行する実行スキル
- `test-run-functional` ほか実行スキル 5 種 — Playwright MCP を利用する実行スキル
