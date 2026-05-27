# Case 03: ailead ソースの時刻ベース突合検証

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | `minutes-composer` の出力完了後、フレッシュなサブエージェントとして起動 |
| 前提ファイル | `workspace/minutes.json`（議事録データ）、`workspace/transcript.txt`（文字起こし全文）、`workspace/response.json`（ailead GraphQL レスポンス） |
| response.json の状態 | `data.externalShare.callSummary.topics` に複数のトピックを含み、各トピックに `dateTime`（秒単位）が設定されている |

## 期待動作

1. メインコンテキストが Agent ツールでフレッシュインスタンスを起動する（作成バイアス排除のため）
2. `workspace/minutes.json`、`workspace/transcript.txt`、`workspace/response.json` の3ファイルを読み込む
3. `response.json` が存在することを検出し、ailead ソースの検証フローに入る
4. `response.json` の `callSummary.topics` 配列から各トピックの情報を取得する:
   - `dateTime`（秒単位の時刻）を起点として使用する
   - `title`、`description`、`speakerName`、`category` を参照する
5. 各トピックについて、`dateTime` を起点に文字起こしセグメントを時刻ベースで特定する:
   - `transcript.txt` の各行の `[HH:MM:SS - HH:MM:SS]` タイムスタンプを秒数に変換する
   - トピックの `dateTime` 付近（前後）のセグメントを特定する
   - 特定したセグメント群の発言内容とトピックの `description` を突合する
6. トピック単位の突合検証を実施する:
   - 要約の正確性: `description` が該当時刻範囲の文字起こし内容と一致するか検証する
   - 発言者の検証: `speakerName` が該当時刻の実際の発話者と一致するか検証する
   - カテゴリの妥当性: SHARE/DISCUSSION/DECISION/CONCERN/SUGGESTION/DIALOGUE/SCHEDULE のいずれが文脈に合致するか確認する
7. 文字起こし全文を通読し、トピックに含まれない決定事項・アクションアイテム・重要議論の漏れを検出する
8. `workspace/verification-log.md` と `workspace/review-result.json` を出力する
9. 修正提案（修正・追加）をメインコンテキストに返却する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/verification-log.md` | 検証サマリー（ailead トピック数・正確と判定した数・修正件数・追加件数）+ 修正・追加の詳細（各項目に ailead トピックの `dateTime` と対応する文字起こしタイムスタンプの引用を含む） |
| `workspace/review-result.json` | 検証結果の構造データ。`corrections`（修正提案）と `additions`（追加提案）を含む。各提案に `topicDateTime`（ailead トピックの時刻）と `transcriptTimestamp`（根拠とした文字起こしの時刻範囲）を含む |
| メインへの返却 | 修正提案のサマリー（修正件数・追加件数・具体的な修正内容の要約） |
| 終了状態 | 成功（検証結果をメインコンテキストに返却し、minutes.json への反映を促す） |

## 分岐の根拠

SKILL.md「入力」表: 「`workspace/response.json`（ailead ソースの場合のみ）」として ailead 生データが検証の追加入力として利用可能であることを明記。`references/verification-rules.md` セクション2「Step 1: トピック単位の突合」: 「トピックの `dateTime` を起点に、前後の文字起こしセグメントを特定する」「要約の正確性検証: トピックの `description` が文字起こしの内容と一致するか確認する」「発言者の検証: トピックの `speakerName` が実際の発言者と一致するか確認する」。同セクション5: 「トピックの `dateTime` は秒単位の値（正規化ではない）」により、`dateTime` を直接秒数として文字起こしのタイムスタンプと照合できる。

## 関連ケース

- `case-01_with_corrections.md`（response.json なしで transcript.txt のみから検証するケース）
- `case-02_no_corrections.md`（修正が不要な場合の通過パス）
