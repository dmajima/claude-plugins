---
name: minutes-composer
description: |
  会議の文字起こしとトピック要約から構造化議事録データ（JSON）を作成するスキル。
trigger:
  - '議事録 または minutes を含む作成依頼（データ取得済みの場合）'
  - 'ailead-fetcher / transcript-converter の出力を受けての議事録構成依頼'
  - '文字起こしテキストを直接提示しての議事録構成依頼'
---

# Minutes Composer

文字起こし・トピック要約から構造化議事録データ（JSON）を作成するスキル。

## 責務

- 文字起こしテキストを分析し、議題・議論内容・決定事項・アクションアイテムを構造化 JSON として出力する
- ailead の場合はトピック要約を骨格として文字起こしと突合検証し構造化する
- 汎用テキストの場合はゼロから構造化する

## 責務外

- データソースからの取得（ailead-fetcher / transcript-converter が担当）
- 最終出力形式への変換（docx-renderer / md-renderer が担当）
- 突合レビュー（minutes-reviewer が担当）

## トリガー条件

- ailead-fetcher / transcript-converter でデータ取得後、議事録構成が必要な場合
- 文字起こしテキストが直接提供された場合

## 前提

- ailead-fetcher または transcript-converter が出力した標準形式（workspace/transcript.txt + workspace/metadata.json）が入力として存在すること
- セッション作業領域の `workspace/` に minutes.json を出力する

## 重要な制約

- 議事録の中間表現を出力形式（docx/md/html）から分離する設計。最終出力は下流スキル（docx-renderer / md-renderer 等）が担当する
- ailead フローと汎用フローで処理パスが異なる

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| workspace/ に transcript.txt + metadata.json が存在 | 非対話 | 入力種別を自動判定して構造化 |
| 入力ファイル不在 | 対話 | データ取得スキル（ailead-fetcher / transcript-converter）の起動を提案 |

## 概要

会議の文字起こしを分析し、議題・議論内容・決定事項・アクションアイテムを抽出して
構造化 JSON 形式で出力する。出力形式に依存しない中間データとして設計されており、
`docx-renderer` 等の下流スキルが最終出力を担当する。

## 入力パターン

| 入力 | 処理フロー |
|------|-----------|
| ailead-fetcher の出力（workspace/transcript.txt + workspace/response.json） | トピック要約ベースの構造化 |
| transcript-converter の出力 | 同上 |
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
| 動作分岐検証 | [`evals/`](evals/) |
