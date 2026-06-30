# Case 07: ailead フロー + callSummary null（generic flow フォールバック）

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | `connector:ailead` の出力完了後に起動される |
| 前提ファイル | `workspace/transcript.txt`, `workspace/metadata.json`, `workspace/response.json`, `workspace/summary.md` がすべて存在する |
| 特殊条件 | `workspace/response.json` 内の `externalShare.callSummary` が `null`（AI 会議要約が未生成）。`workspace/metadata.json` の `topicCount` が `0` |
| 判定根拠 | `workspace/response.json` の存在により ailead フローと判定されるが、`callSummary` が null のためトピック骨格が利用不可 |

## 期待動作

1. `workspace/` 配下のファイルを読み込む（transcript.txt, metadata.json, response.json）
2. `response.json` の存在を検出し、ailead フローを選択する
3. `response.json` 内の `callSummary` を確認する
4. `callSummary` が null であることを検出し、トピック要約ベースの骨格構成が不可能と判断する
5. **`ailead-flow.md` Step 3 のフォールバック規定に従い、`generic-flow.md` の Step 2 以降（文字起こしからのゼロ構造化）に切替える**
   - メタデータの整理（Step 2）までは ailead フローの手順を使用する（ailead 固有の参加者情報・開始日時等を metadata.json から取得）
6. 文字起こしからトピック境界を識別し議題構造を構成する（generic flow 相当）
7. 会議全体から決定事項・アクションアイテム・次回予定を抽出する
8. `workspace/minutes.json` としてスキーマ準拠の JSON を出力する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/minutes.json` | `references/schema/minutes-schema.md` v2.0 に準拠した JSON。`metadata.source` は `"ailead"` を維持。`agendas` は文字起こしからのゼロ構造化による議題（トピック要約ベースではない） |
| JSON 構造 | `version: "2.0"`、`metadata`（ailead メタデータから構成）、`agendas`（ゼロ構造化）、`actionItems`、`nextMeeting` |
| 終了状態 | 成功（minutes-reviewer への引き渡し可能な状態） |

## 分岐の根拠

`references/steps/ailead-flow.md` Step 3 のフォールバック規定: 「`callSummary` が null または `topics` が空の場合、トピック骨格は構成できないため `generic-flow.md` の Step 2 以降（文字起こしからのゼロ構造化）に切替える。メタデータの整理（Step 2）までは本フローの手順を使用してよい。」これにより ailead フロー判定後でも generic flow にフォールバックする分岐が存在する。

connector:ailead の case-08（callSummary null）が正常終了した後に minutes-composer がその出力を受け取った場合に発生するパス。

## 関連ケース

- `case-01_ailead_flow.md`（callSummary が存在する正常な ailead フロー）
- `case-02_generic_flow.md`（response.json 自体が不在の場合のゼロ構造化）
