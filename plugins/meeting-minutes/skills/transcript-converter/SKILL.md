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

- 多様な形式の文字起こしデータを読み取り、ailead-fetcher と同一の出力形式に正規化する
- 入力形式を自動判定し、発話者・タイムスタンプ・テキストを抽出して標準形式に変換する
- セッション作業領域の `workspace/` に transcript.txt と metadata.json を出力する

## 責務外

- 音声ファイルからの文字起こし（STT）
- ailead 共有リンクからの取得（ailead-fetcher が担当）
- 議事録の構造化（minutes-composer が担当）

## トリガー条件

- ユーザーが文字起こしテキストを直接貼り付けた場合
- VTT/SRT ファイルを提供した場合
- Teams チャットからコピーした文字起こしを提供した場合

## 前提

- データソースごとに minutes-composer を分岐させず、統一された中間形式を経由して処理する設計
- ailead-fetcher と同一の出力形式にすることで、下流スキル（minutes-composer / minutes-reviewer）がソースに依存しない

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
`ailead-fetcher` と同一の出力形式（`transcript.txt` + `metadata.json`）に正規化する。
これにより `minutes-composer` と `minutes-reviewer` がデータソースに依存せず動作できる。

## 対応入力形式

| 形式 | 拡張子 / パターン | 発話者 | タイムスタンプ | 自動判定 |
|------|-----------------|--------|-------------|---------|
| WebVTT | `.vtt` | `<v 名前>テキスト</v>` | HH:MM:SS.mmm --> HH:MM:SS.mmm | Yes |
| SRT | `.srt` | セグメント内のテキスト（発話者なし） | HH:MM:SS,mmm --> HH:MM:SS,mmm | Yes |
| Teams コピペ | テキスト | `名前 HH:MM` の行 + 発言行 | HH:MM（分単位） | Yes |
| ailead transcript.txt | テキスト | `[HH:MM:SS - HH:MM:SS] 名前: テキスト` | HH:MM:SS | Yes |
| プレーンテキスト | `.txt` / 直接入力 | なし or 推定 | なし | Fallback |

## 出力形式（標準構造）

ailead-fetcher と同一の形式で出力する:

### transcript.txt

```
[HH:MM:SS - HH:MM:SS] 発話者名: テキスト
[HH:MM:SS - HH:MM:SS] 発話者名: テキスト
...
```

### metadata.json

```json
{
  "title": "会議タイトル（入力から推定 or ユーザー指定）",
  "startDatetime": "2026-05-26T15:00:00+09:00",
  "duration": 3823,
  "system": "teams / zoom / unknown",
  "participants": [
    { "name": "発話者名", "talkRatio": 0.0 }
  ],
  "source": "vtt | srt | teams-paste | plain | manual",
  "hostUser": ""
}
```

## 実行フロー

1. 入力の種別を判定する（ファイルパス or 直接テキスト）
2. ファイルの場合は読み込む。テキストの場合は `inputs/` に保存する
3. 形式を自動判定する（VTT / SRT / Teams コピペ / プレーンテキスト）
4. 形式に応じたパーサーで発話者・タイムスタンプ・テキストを抽出する
5. 標準形式（`transcript.txt` + `metadata.json`）に変換して `workspace/` に出力する
6. メタデータが不足する場合（会議タイトル・日時等）はユーザーに確認する

詳細: [`references/procedures.md`](references/procedures.md)
形式判定ロジック: [`references/format-detection.md`](references/format-detection.md)

## 形式自動判定の優先順

1. ファイル拡張子（`.vtt` → VTT、`.srt` → SRT）
2. 先頭行の内容（`WEBVTT` → VTT、数字のみ → SRT）
3. 行パターン（`[HH:MM:SS` → ailead 形式、`名前 HH:MM` → Teams コピペ）
4. 上記いずれにも合致しない → プレーンテキスト

## メタデータ推定ルール

| フィールド | 推定方法 |
|-----------|---------|
| `title` | ファイル名から抽出（拡張子除去）。不明ならユーザーに確認 |
| `duration` | 最終セグメントの endTime - 最初のセグメントの startTime |
| `participants` | 発話者名の一覧を抽出。talkRatio は文字数ベースで概算 |
| `source` | 形式判定結果を設定 |
| `system` | VTT + `<v>` タグ → teams（推定）。不明なら `unknown` |

## Python スクリプト

```powershell
& chcp.com 65001 | Out-Null
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$venvPy = "$SESSION_DIR\workspace\.venv\Scripts\python.exe"
& $venvPy "${env:CLAUDE_SKILL_DIR}\scripts\convert\convert_transcript.py" `
  --input "<入力ファイルパスまたは stdin>" `
  --output "$SESSION_DIR\workspace"
```

## 参照

| 用途 | ファイル |
|-----|---------|
| 変換手順 | [`references/procedures.md`](references/procedures.md) |
| 形式判定ロジック | [`references/format-detection.md`](references/format-detection.md) |
