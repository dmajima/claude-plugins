# case-02 仕様書指定あり（spec= と requirement 対応付け）

`spec=` 引数で仕様書が指定されたケース。仕様書を分析の一次情報源とし、全ケースの requirement を仕様書の要件 ID・節番号へ対応付けることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web 対象説明=https://localhost:5001 spec=docs/requirements/spec.md levels=functional,system` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | `docs/requirements/spec.md` に要件 ID（REQ-AUTH-01 等）と受入基準を含む仕様書が存在 / `{target-slug}/` は初期化済みでケース未作成 |

## 分岐の根拠

SKILL.md「前提」の引数表（`spec=` は仕様書パス）と「検証」（requirement 対応付け）、references/design-procedures.md 3.1 章（spec あり: 要件 ID・機能一覧・受入基準の抽出）、references/case-design-principles.md 1 章（requirement トレーサビリティ: 全ケースの requirement に要件参照を設定）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（requirement 必須フィールド）。

## 期待動作

- `docs/requirements/spec.md` を Read で読解し、要件 ID・機能一覧・画面一覧・受入基準を抽出する
- 委譲で `target-slug=` を受領しているため、slug の解決フロー・確認は行わない
- `levels=functional,system` 指定のためレベル提案・AskUserQuestion を行わず指定を採用する
- 生成する全ケースの `requirement` フィールドに仕様書の要件 ID または節番号を設定する（「仕様書参照」のような曖昧な値にしない）
- 仕様書に記載があるのにケース化していない主要機能を作らない（網羅の突合は仕様書の機能一覧に対して行う）
- 仕様書から読み取れなかった事項（画面遷移の詳細等）は推測で補わず、返却の未確認事項に列挙する
- test-plan.md の対象概要に情報源として仕様書パスを記録する
- test-architect 自己チェックのプロンプトに要件 / 仕様情報を含める（agents.md 4.2 章の test-architect 追加入力）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/test-plan.md`（対象概要に仕様書パスを記録）・`test-cases.yaml`（全ケース `review_status: draft`、`requirement` に仕様書の要件 ID / 節番号を設定）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 生成結果のサマリ（functional / system のレベル構成・生成ケース ID・仕様書要件との対応付け）と、仕様書から読み取れなかった未確認事項の列挙 |
| 終了状態 | test-architect の自己チェック後、全ケース `review_status: draft` で委譲元へ返却。単独完結せず後続の設計レビューへ |

## 関連ケース

- case-01: 仕様書なしの分析（リポジトリ探索が一次情報源）
- case-03: レベル指定の採用動作
