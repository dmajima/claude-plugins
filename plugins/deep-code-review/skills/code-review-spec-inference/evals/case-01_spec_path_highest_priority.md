# case-01 仕様書明示（spec= 最高優先）

pr-review の Step 3.5 から `spec=<path>` 付きで委譲されるケース。明示された仕様書を決定的根拠（優先度 1）として採用し、外部 fetch は発生しない。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `spec=docs/specs/order.md` / PR description あり（構造化見出しを含む）/ 外部リンクなし / `fetch-external` 未指定（既定 `ask`） |
| モード | 委譲呼び出し（pr-review Step 3.5 から Skill ツール経由・対話） |

## 分岐の根拠

SKILL.md「ステップ詳細」Step 1 の優先順位 1「`spec=<path>` で明示された仕様書（最高: 決定的根拠）」、SKILL.md「入力」表（仕様書パス `spec=<path1>[,<path2>...]` = 明示された仕様書（最高優先）、`fetch-external` の既定は `ask`）、references/expected-behavior.md セクション 1「入力の優先順位」表（優先 1: `spec=<path>` 重み最高（決定的根拠）、優先 2: PR description（タイトル直下の本文）高）、references/checklist.md セクション B の I1 / I5。

## 期待動作

- `spec=` で明示された仕様書を Read で読み込み、優先度 1 の決定的根拠として期待挙動サマリの中核に採用する
- PR description の構造化見出し（references/expected-behavior.md セクション 2.1 の見出しパターン）は優先度 2 の補完情報として扱う
- 外部リンクが存在しないため Step 2 の外部 fetch は行わず、dry-run の fetch 候補一覧提示も発生しない
- 出力 JSON は 5 フィールド構造（expected_behavior_summary / requirements / acceptance_criteria / conflicts / sources_used）とする（I5、references/checklist.md セクション C の C-Auto-2）
- sources_used の先頭に `{"type": "spec", "path": "docs/specs/order.md", "priority": 1}` を置き、全エントリに type / priority を付与する（SKILL.md「出力」、checklist C-Auto-3）
- 矛盾が検出されない場合も conflicts フィールド自体は出力 JSON に含める（I5 の 5 フィールド構造）
- Write / Edit は使用せず、推論結果の出力のみでファイル変更を行わない（SKILL.md 権限ポリシーおよび「重要な制約」）

## 関連ケース

- case-02: 仕様書なし・外部リンク fetch（fetch-external=auto）
- case-03: 仕様書なし・情報源間の矛盾検出
