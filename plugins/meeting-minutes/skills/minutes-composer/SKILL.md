---
name: minutes-composer
description: |
  会議の文字起こしとトピック要約から構造化議事録データ（JSON）を作成するスキル。
  What: 文字起こしテキストを分析し、議題・議論内容・決定事項・アクションアイテムを構造化 JSON として出力する。
  Where: セッション作業領域に minutes.json を出力する。
  When: ailead-fetcher / teams-fetcher でデータ取得後、または文字起こしテキストが直接提供された場合。
  Why: 議事録の中間表現を出力形式（docx/md/html）から分離し、下流スキル（minutes-docx 等）と組み合わせ可能にする。
  How: ailead の場合はトピック要約を骨格として文字起こしと突合検証し構造化する。汎用テキストの場合はゼロから構造化する。
  責務外: データソースからの取得（ailead-fetcher / teams-fetcher が担当）。最終出力形式への変換（minutes-docx が担当）。突合レビュー（minutes-reviewer が担当）。
trigger:
  - 「議事録」「minutes」を含む作成依頼（データ取得済みの場合）
  - ailead-fetcher / teams-fetcher の出力を受けての議事録構成依頼
  - 文字起こしテキストを直接提示しての議事録構成依頼
---

# Minutes Composer

文字起こし・トピック要約から構造化議事録データ（JSON）を作成するスキル。

## 概要

会議の文字起こしを分析し、議題・議論内容・決定事項・アクションアイテムを抽出して
構造化 JSON 形式で出力する。出力形式に依存しない中間データとして設計されており、
`minutes-docx` 等の下流スキルが最終出力を担当する。

## 入力パターン

| 入力 | 処理フロー |
|------|-----------|
| ailead-fetcher の出力（transcript.txt + response.json） | トピック要約ベースの構造化 |
| teams-fetcher の出力（将来） | 同上 |
| 汎用文字起こしテキスト | ゼロからの構造化 |

## 出力: minutes.json

議事録の構造化データを JSON 形式で出力する。

スキーマ定義: [`references/schema/minutes-schema.md`](references/schema/minutes-schema.md)

## 実行フロー

1. 入力データの種別を判定する（ailead / teams / 汎用）
2. 会議メタデータを構成する
3. ailead の場合: トピック要約を骨格として議題構造を構成する
4. 汎用の場合: 文字起こしからトピック境界を識別し議題構造を構成する
5. 各議題について議論内容・確認事項を抽出する
6. 会議全体から決定事項を抽出する
7. 会議全体からアクションアイテムを抽出する
8. 次回予定を抽出する
9. `minutes.json` として出力する

詳細手順:
- ailead フロー: [`references/steps/ailead-flow.md`](references/steps/ailead-flow.md)
- 汎用フロー: [`references/steps/generic-flow.md`](references/steps/generic-flow.md)

## 参照

| 用途 | ファイル |
|-----|---------|
| JSON スキーマ | [`references/schema/minutes-schema.md`](references/schema/minutes-schema.md) |
| 議事録 Markdown テンプレート（参考） | [`references/template/minutes-template.md`](references/template/minutes-template.md) |
| ailead フロー手順 | [`references/steps/ailead-flow.md`](references/steps/ailead-flow.md) |
| 汎用フロー手順 | [`references/steps/generic-flow.md`](references/steps/generic-flow.md) |
