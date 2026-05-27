# Case 02: 汎用フロー（ゼロからの構造化）

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | `transcript-converter` の出力完了後に起動される |
| 前提ファイル | `workspace/transcript.txt` と `workspace/metadata.json` のみが存在する |
| 判定根拠 | `workspace/response.json` が存在しないことにより汎用フローと判定される |

## 期待動作

1. `workspace/` 配下のファイルを読み込む（transcript.txt, metadata.json）
2. `response.json` が存在しないことを検出し、汎用フローを選択する
3. 文字起こし全文を分析し、トピック境界を識別する:
   - 話題の切り替わりを文脈から検出する
   - 長い沈黙や「次の議題」等の明示的な境界マーカーを利用する
4. 識別した各トピックについて:
   - 議題名を文脈から生成する
   - 議論内容を要約する
   - 確認事項を抽出する
5. 会議全体から決定事項を抽出する（「～にしましょう」「～で決定」等のパターン検出）
6. 会議全体からアクションアイテムを抽出する（「～さん、確認お願い」「次回までに～」等のパターン検出）
7. 次回予定を抽出する
8. `workspace/minutes.json` としてスキーマ準拠の JSON を出力する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/minutes.json` | `references/schema/minutes-schema.md` v2.0 に準拠した JSON。`agendas` 配列にゼロから識別された議題（各議題の `conclusions` に決定事項を統合）、`actionItems` にアクションアイテムを含む |
| JSON 構造 | `version: "2.0"`、`metadata`（metadata.json から構成）、`agendas`（1件以上）、`actionItems`、`nextMeeting` の各セクションを含む |
| 終了状態 | 成功（minutes-reviewer への引き渡し可能な状態） |

## 分岐の根拠

SKILL.md「入力パターン」表: 「汎用文字起こしテキスト → ゼロからの構造化」。SKILL.md「実行フロー」ステップ4: 「汎用の場合: 文字起こしからトピック境界を識別し議題構造を構成する」。詳細手順は `references/steps/generic-flow.md` に記載。

## 関連ケース

- `case-01_ailead_flow.md`（response.json がある場合のトピック要約ベース構造化）
