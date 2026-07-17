# code-review-spec-inference スキル

PR description / コメント / 外部リンク先資料 / 明示仕様書から、PR がもたらす「あるべき姿（期待挙動）」を推論するスキル。
コードレビュー時の判定根拠となる **期待挙動サマリ（JSON）** を生成する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 提供機能

| 機能 | 内容 |
|------|------|
| 情報源の優先順位付き収集 | 仕様書 > description 構造化見出し > 外部リンク > リポジトリ内資料 > 過去コメント > Bot 過去レビュー |
| 外部リンク fetch | Backlog / TFS Boards / Wiki 等の外部資料をドメインホワイトリスト方式で安全に取得 |
| 取得結果のサニタイズ | プラグイン共通のサニタイズ規則適用・認証情報パターンの伏字化 |
| 期待挙動サマリの構築 | 要件・受入条件を構造化した JSON を生成 |
| 矛盾事項の検出 | 複数情報源間の矛盾（仕様書 vs description 等）を検出し `conflicts` に格納 |

## 使い方

### 呼び出し経路

主に他スキルから Skill ツール経由で呼び出される（ユーザーが直接起動する場面は少ない）。

| 経路 | 用途 |
|------|------|
| pr-review の Step 3.5（期待挙動の推論） | `spec=<path>` 引数なしで PR をレビューする際の仕様書代替、外部リンク先資料からの期待挙動抽出 |
| code-review オーケストレーター | 仕様書代替として期待挙動サマリを取得 |

仕様書が複数あって矛盾する場合の優先順位判定にも使用される。

### 主な引数

| 引数 | 内容 |
|------|------|
| PR description / コメント一覧 | pr-review 経由で取得した PR の自然言語情報 |
| `spec=<path1>[,<path2>...]` | 明示された仕様書（最高優先の情報源） |
| `fetch-external=ask / auto / off` | description 内外部リンクの自動 fetch 動作（既定: `ask`） |

## 出力

以下の 5 フィールドで構成される JSON を返却する。

| フィールド | 内容 |
|-----------|------|
| `expected_behavior_summary` | 期待挙動の要約（自然言語） |
| `requirements` | 要件の一覧 |
| `acceptance_criteria` | 受入条件の一覧 |
| `conflicts` | 情報源間の矛盾点 |
| `sources_used` | 使用した情報源（種別・優先度・fetch 結果） |

## ファイル構成

```
plugins/deep-code-review/skills/code-review-spec-inference/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── evals/                                # 動作分岐検証ケース（case-01〜07 + README）
└── references/
    ├── checklist.md                      # 出力 JSON 返却前の達成チェックリスト
    └── expected-behavior.md              # 期待挙動の推論ロジック詳細
```

## スコープ外

- PR コメント投稿（pr-review が担当）
- コードレビュー本体（code-review オーケストレーター + 観点別スキルが担当）
- ファイル変更（Write / Edit は許可しない。推論結果の出力のみ）
- 未解決コメントの解消判定（PR ホスト対応スキルが担当）

## 関連スキル

- `pr-review` — 本スキルの主な呼び出し元（PR I/O アダプタ層）
- `code-review` — オーケストレーター（仕様書代替として本スキルを利用）
