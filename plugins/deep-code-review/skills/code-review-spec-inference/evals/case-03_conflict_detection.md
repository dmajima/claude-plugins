# case-03 情報源間の矛盾検出（conflicts 出力）

仕様書なしで、description の構造化見出しと過去の人間レビュアーコメントが食い違うケース。優先度の高い description 側を採用し、矛盾点を conflicts フィールドに格納する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `spec` なし / description に「## 期待挙動」見出しあり / 過去コメント（人間レビュアー）に description と食い違う制約の言及あり / 外部リンクなし / `fetch-external` 未指定（既定 `ask`） |
| モード | 委譲呼び出し（対話） |

## 分岐の根拠

SKILL.md「ステップ詳細」Step 5「複数情報源間の矛盾（仕様書 vs description / 過去コメント vs description 等）を検出し、出力 JSON の conflicts フィールドに格納する」、references/expected-behavior.md セクション 1 末尾「複数情報源で矛盾がある場合は優先度の高い情報源を採用し、矛盾点を完了報告に明示する」と同セクションの優先順位表（優先 2: PR description 高 / 優先 5: PR の過去コメント（人間レビュアーの指摘・要望）中）、同セクション 2.1（「## 期待挙動」等の見出し直下の本文を優先度高く扱う）・セクション 4.1（人間レビュアーコメントからの要望・制約の抽出）、references/checklist.md セクション B の I1 / I4。

## 期待動作

- description の「## 期待挙動」見出し直下の本文を優先度 2 の情報源として抽出する（expected-behavior.md セクション 2.1）
- 過去の人間レビュアーコメントから要望・制約を抽出し、優先度 5（中）の情報源として扱う（expected-behavior.md セクション 1 表・セクション 4.1）
- 両者の食い違いを矛盾として検出し、優先度の高い description 側を expected_behavior_summary / requirements に採用する（expected-behavior.md セクション 1 末尾）
- 採用しなかった情報源との矛盾点を出力 JSON の conflicts フィールドに格納する（SKILL.md Step 5、checklist I4）
- conflicts の記述は「情報源 A は X、情報源 B は Y。優先度に従い X を採用」のように、どの情報源がどう食い違いどちらを採用したか追跡できる形式とする（expected-behavior.md セクション 6「矛盾 / 未確定事項」の例示形式）
- sources_used に両情報源を type / priority 付きで列挙する（I1、checklist C-Auto-3）
- 外部リンクがないため外部 fetch は発生しない
- 出力 JSON は 5 フィールド構造を維持する（I5）

## 関連ケース

- case-01: 仕様書明示（spec= があれば矛盾時もそれが決定的根拠となる対比）
- case-02: 外部リンク fetch の分岐
