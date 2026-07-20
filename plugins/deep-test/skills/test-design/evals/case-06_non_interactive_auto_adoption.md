# case-06 非対話モード × 既存 slug 1 件（自動採用と設計完遂）

`--non-interactive` でのテスト設計委譲で、唯一の既存 target-slug とレベル提案を自動採用し、採用根拠を明記して設計を完遂することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ --non-interactive`（`target-slug=` と `levels=` の指定なし） |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・非対話） |
| 前提 | 基準ディレクトリ配下の既存 `{target-slug}/` は **1 件のみ**（`orderapp-web/`） |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: レベル提案を自動採用・target-slug 解決は data-locations.md 4.2 章の非対話規則）、references/design-procedures.md 2 章（単独・委譲での slug 確定。非対話時は唯一の既存 slug 採用）・4.1 章（レベル提案の作成: 分析結果からの判定目安表）・4.2 章（非対話は提案を自動採用し、採用根拠〔上表のどの判定に該当したか〕を返却に明記する）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.2 章（非対話時は唯一の既存 slug を採用）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- target-slug の解決で唯一の既存 slug（`orderapp-web`）を自動採用する（新規 slug を作らない・確認も挟まない）
- `levels=` 未指定のため対象分析からレベル提案を作成し、**提案を自動採用**する。採用根拠（design-procedures.md 4.1 章の判定目安表のどの判定に該当したか）を返却に明記する
- test-plan.md と test-cases.yaml を生成する（全ケース `review_status: draft`・revision: 1）
- test-architect の自己チェックを経てから返却する（非対話でも省略しない）
- 返却に「全ケース draft のため test-review（設計文脈）の承認が必要」を含める
- test-results.yaml へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `orderapp-web/` 配下の test-plan.md・test-cases.yaml（全ケース `review_status: draft`）。test-results.yaml への書き込みなし |
| 標準出力（要約） | 自動採用の根拠（slug = 唯一の既存 / レベル = 4.1 章のどの判定に該当したか）を明記した生成サマリ（レベル別ケースサマリ・test-architect 所見・未確認事項・draft 承認が必要な旨） |
| 終了状態 | AskUserQuestion を呼ばず draft 返却で設計を完遂し後続レビューへ |

## 関連ケース

- case-05: 同じ非対話で既存 slug が複数の場合（自動選択せずエラー中断する側）
- case-01: 対話モードでの確認フロー（AskUserQuestion 使用）
- case-03: レベル明示指定（非対話でも指定があれば採用）
