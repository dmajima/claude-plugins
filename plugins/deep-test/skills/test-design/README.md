# test-design スキル

deep-test プラグインのテスト設計フェーズを担うスキル。テスト対象を分析し、テスト計画（test-plan.md）・対象テストレベルの選定・テストケース（test-cases.yaml）の設計までを一貫して行う。
生成したケースは test-architect エージェントの自己チェックを経て返却され、その後 test-review（設計文脈）の承認を受けてはじめて実行対象になる。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 導入手順

本スキル `test-design` は `deep-test` プラグインに同梱されており、**追加インストールは不要**です。プラグインの導入手順（マーケットプレイス登録・インストール・自動更新の設定）は [`deep-test` プラグインの README](../../README.md) を参照してください。

- **起動トリガー**: オーケストレータ `test` の design フェーズ・design-only モードからの委譲、または「テスト計画を作って」「このアプリのテストケースを設計して」等の自然言語依頼での単独起動

## 何をするか

| ステップ | 内容 |
|---------|------|
| 対象分析 | 仕様書（`spec=`）・リポジトリ・アプリ URL の情報から機能・画面・API・外部 IF 構成を把握 |
| レベル選定 | 8 テストレベル（ユニット / 単体 / 内部結合 / 外部結合 / システム / UAT / 性能 / セキュリティ）から対象を選定。未指定時は分析結果から提案し AskUserQuestion で確定 |
| test-plan.md 生成 | 対象概要・テスト方針・レベル別スコープ・環境前提・データ方針・スケジュール目安の 6 セクション |
| test-cases.yaml 生成・更新 | ID 採番 `TC-{LEVEL}-{3桁}`・`revision: 1`・`review_status: draft`。境界値・同値分割・異常系・ユーザー目線シナリオを含む Playwright 実行可能なケースを設計。既存更新時は revision +1・draft 戻し・deprecated 論理削除の版管理規則を遵守 |
| 自己チェック | test-architect エージェントで計画・レベル選定・ケースの妥当性を確認し、重大指摘を反映してから返却 |

## 使い方

### トリガーフレーズ例

```
テスト計画を作って
このアプリのテストケースを設計して
仕様変更に合わせてテストケースを更新して
```

### 起動経路

| 経路 | 説明 |
|------|------|
| test オーケストレータ経由 | フルフローの design フェーズ・design-only モードとして Skill ツール経由で委譲される |
| 単独起動 | 上記トリガーフレーズで本スキルのみを直接実行する |

### 引数

| 引数 | 内容 |
|------|------|
| `対象説明=` | テスト対象（アプリ URL・リポジトリパス・対象名） |
| `spec=<パス>` | 仕様書（ファイルまたはディレクトリ）。ケースの requirement 対応付けに使用 |
| `levels=functional,system` | 対象レベルの明示指定（未指定時は提案 → 確定） |
| `target-slug=<slug>` | 解決済み slug（委譲時にオーケストレータが渡す） |
| `--non-interactive` | 非対話モード（レベル提案を自動採用） |

## 動作例

入力: 「https://localhost:5001 の受注管理アプリのテストを設計して。仕様書は docs/spec.md」

1. docs/spec.md を読解し、機能・画面・API・要件 ID を抽出
2. レベル提案（functional / integration-internal / system / security 等）を AskUserQuestion で確定
3. `.claude/.local/plugins/deep-test/{target-slug}/test-plan.md` を生成
4. 同 `test-cases.yaml` を生成（全ケース draft・境界値 / 異常系込み）
5. test-architect の自己チェック → 指摘反映 → 設計結果サマリを返却

## 出力

- `{target-slug}/test-plan.md` / `{target-slug}/test-cases.yaml`（配置規約は plugin references の data-locations.md）
- 設計結果サマリ（選定レベルと根拠・レベル別ケース数・test-architect 所見・未確認事項）

## ファイル構成

```
plugins/deep-test/skills/test-design/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── references/
│   ├── design-procedures.md              # 分析 → 計画 → ケース設計 → 自己チェックの詳細手順
│   └── case-design-principles.md         # ケース設計原則（技法・レベル別観点・Playwright 実行可能性基準）
└── evals/                                # 動作分岐検証ケース（case-01〜05 + README）
```

## スコープ外

- ケースのレビュー・承認（`test-review` 設計文脈が担当。本スキルは review_status を approved にしない）
- テストの実行・実績記録（`test-run-*` / オーケストレータ `test`）
- 環境構築（`test-setup`）・報告書生成（`test-report`）
- ユニットテストのテストコード実装（ケース定義の設計まで）

## 関連スキル

- `test` — オーケストレータ（design フェーズの委譲元・設計レビューゲートの判定）
- `test-review` — 設計文脈で本スキルの成果物をレビュー・承認する
- `test-setup` — 実行環境の事前検証（feasibility 評価の環境情報源）
