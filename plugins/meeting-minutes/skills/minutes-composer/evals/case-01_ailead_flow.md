# Case 01: ailead フロー（トピック要約ベース構造化）

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | `connector:ailead` の出力完了後に起動される |
| 前提ファイル | `workspace/transcript.txt`, `workspace/metadata.json`, `workspace/response.json`, `workspace/summary.md` がすべて存在する |
| 判定根拠 | `workspace/response.json` の存在により ailead フローと判定される |

## 期待動作

1. `workspace/` 配下のファイルを読み込む（transcript.txt, metadata.json, response.json）
2. `response.json` の存在を検出し、ailead フローを選択する
3. `response.json` 内の `callSummary.topics` をトピック要約の骨格として使用する
4. 各トピックについて:
   - トピックの `dateTime` を起点に、前後の文字起こしセグメントを特定する
   - トピックの `description` と文字起こしを突合し、議題内容を構成する
   - `speakerName` を発言者として設定する
   - カテゴリ（SHARE/DISCUSSION/DECISION 等）に応じて議題の分類を決定する
5. 会議全体から決定事項を抽出する（「～にしましょう」「～で決定」等のパターン検出）
6. 会議全体からアクションアイテムを抽出する（「～さん、確認お願い」「次回までに～」等のパターン検出）
7. 次回予定を抽出する
8. `workspace/minutes.json` としてスキーマ準拠の JSON を出力する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/minutes.json` | `references/schema/minutes-schema.md` v2.0 に準拠した JSON。`agendas` 配列にトピックベースの議題（各議題の `conclusions` に決定事項を統合）、`actionItems` にアクションアイテムを含む |
| JSON 構造 | `version: "2.0"`、`metadata`（メタデータから構成）、`agendas`（トピック数と同数以上）、`actionItems`、`nextMeeting` の各セクションを含む |
| 終了状態 | 成功（minutes-reviewer への引き渡し可能な状態） |

## 分岐の根拠

SKILL.md「入力パターン」表: 「connector:ailead の出力（workspace/transcript.txt + workspace/response.json）→ トピック要約ベースの構造化」。SKILL.md「実行フロー」ステップ3: 「ailead の場合: トピック要約を骨格として議題構造を構成する」。詳細手順は `references/steps/ailead-flow.md` に記載。

## 関連ケース

- `case-02_generic_flow.md`（response.json がない場合のゼロからの構造化）
