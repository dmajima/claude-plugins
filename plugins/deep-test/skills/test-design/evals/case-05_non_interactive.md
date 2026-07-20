# case-05 非対話モード × 既存 slug 複数（エラー中断）

`--non-interactive` でのテスト設計委譲で、target-slug が確定できない（既存 slug が複数存在する）場合のエラー中断を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ --non-interactive`（`target-slug=` と `levels=` の指定なし） |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・非対話） |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が **2 件**存在する（`orderapp-web/` と `inventory-app/`） |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: target-slug 解決は data-locations.md 4.2 章の非対話規則）、references/design-procedures.md 2 章（単独・委譲での slug 確定）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.2 章（非対話時は唯一の既存 slug を採用。複数存在時はエラーで中断・slug の明示指定を案内）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: target-slug 複数はエラー中断・自動選択しない）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- target-slug の解決で既存 slug が 2 件あるため、**エラーで中断**する（どちらかを自動選択しない・新規作成もしない）
- 中断時の返却に「複数の既存 target-slug が存在するため中断した」旨と、`target-slug=` の明示指定による再実行の案内を含める
- 中断までに test-plan.md / test-cases.yaml を生成・変更しない（誤った対象への書き込み防止）
- test-results.yaml へも書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（中断までに test-plan.md / test-cases.yaml を生成・変更しない。test-results.yaml へも書き込まない） |
| 標準出力（要約） | 「複数の既存 target-slug が存在するため中断した」旨と `target-slug=` 明示指定による再実行の案内 |
| 終了状態 | AskUserQuestion を呼ばずエラーで中断（slug の自動選択・新規作成をしない） |

## 関連ケース

- case-06: 同じ非対話で既存 slug が 1 件のみの場合（自動採用して設計を完遂する側）
- case-01: 対話モードでの確認フロー（AskUserQuestion 使用）
- case-03: レベル明示指定（非対話でも指定があれば採用）
