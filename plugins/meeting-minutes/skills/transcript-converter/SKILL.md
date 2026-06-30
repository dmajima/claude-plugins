---
name: transcript-converter
description: |
  汎用の文字起こしテキスト・ファイル（VTT / SRT / プレーンテキスト / Teams エクスポート等）を、本プラグイン共通の標準構造（transcript.txt + metadata.json）に変換するスキル。
trigger:
  - '文字起こしテキストが直接貼り付けられた場合'
  - 'VTT / SRT / テキストファイルのパスが提示された場合'
  - 'この文字起こしから議事録を作って 等の依頼で、ailead リンクではない場合'
  - 'Teams の文字起こしコピーペーストが提供された場合'
---

# Transcript Converter

汎用の文字起こしテキスト・ファイルを本プラグイン共通の標準構造に変換するスキル。

## 責務

- 多様な形式の文字起こしデータを読み取り、connector:ailead と同一の出力形式に正規化する
- 入力形式を自動判定し、発話者・タイムスタンプ・テキストを抽出して標準形式に変換する
- セッション作業領域の `workspace/` に transcript.txt と metadata.json を出力する

## 責務外

- 音声ファイルからの文字起こし（STT）
- ailead 共有リンクからの取得（connector:ailead が担当）
- 議事録の構造化（minutes-composer が担当）

## トリガー条件

- ユーザーが文字起こしテキストを直接貼り付けた場合
- VTT/SRT ファイルを提供した場合
- Teams チャットからコピーした文字起こしを提供した場合

## 前提

- データソースごとに minutes-composer を分岐させず、統一された中間形式を経由して処理する設計
- connector:ailead と同一の出力形式にすることで、下流スキル（minutes-composer / minutes-reviewer）がソースに依存しない

## 重要な制約

- 音声・動画ファイルからの直接文字起こし（STT）は対象外
- 形式自動判定が失敗した場合はプレーンテキストとしてフォールバックする

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| ファイルパスが指定されている | 非対話 | 形式自動判定して変換 |
| テキストが直接貼り付けられた | 対話 | メタデータ（タイトル・日時等）が推定不能な場合ユーザーに確認 |

## 概要

多様な形式の文字起こしデータ（VTT / SRT / プレーンテキスト / Teams コピペ等）を読み取り、
`connector:ailead` と同一の出力形式（`transcript.txt` + `metadata.json`）に正規化する。
これにより `minutes-composer` と `minutes-reviewer` がデータソースに依存せず動作できる。

## 対応入力形式

WebVTT / SRT / Teams コピペ / ailead 形式 / プレーンテキスト（フォールバック）の5形式に対応。
詳細は [`references/format-detection.md`](references/format-detection.md) を参照。

## 出力形式

connector:ailead と同一の標準構造（`workspace/transcript.txt` + `workspace/metadata.json`）で出力する。

## 実行フロー

1. 入力の種別を判定する（ファイルパス or 直接テキスト）
2. ファイルの場合は読み込む。テキストの場合は `inputs/` に保存する
3. 形式を自動判定する（VTT / SRT / Teams コピペ / プレーンテキスト）
4. 形式に応じたパーサーで発話者・タイムスタンプ・テキストを抽出する
5. 標準形式（`transcript.txt` + `metadata.json`）に変換して `workspace/` に出力する
6. メタデータが不足する場合（会議タイトル・日時等）はユーザーに確認する

詳細: [`references/procedures.md`](references/procedures.md)
形式判定ロジック: [`references/format-detection.md`](references/format-detection.md)

## 参照

| 用途 | ファイル |
|-----|---------|
| 環境構築 | [`references/setup.md`](references/setup.md) |
| 変換手順 | [`references/procedures.md`](references/procedures.md) |
| 形式判定ロジック | [`references/format-detection.md`](references/format-detection.md) |
| 動作分岐検証 | [`evals/`](evals/) |
