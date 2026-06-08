---
name: ailead-fetcher
description: |
  ailead の外部共有リンク（dashboard.ailead.app/share/...）から動画(HLS)・文字起こし・AI会議要約・参加者情報を GraphQL API 経由で取得するスキル。
trigger:
  - 'ailead と 共有 または share が含まれる依頼'
  - 'dashboard.ailead.app/share/ を含む URL が提示された場合'
  - 'ailead の録画・文字起こし・議事録の取得を依頼された場合'
---

# ailead Fetcher

ailead の外部共有リンクから動画・音声・文字起こし・AI会議要約を取得するスキル。

## 責務

- ailead 共有リンクのデータ（動画URL・transcript・summary・参加者）を GraphQL API 経由で抽出する
- HTML から buildId を抽出し、事前解析済みの operationHash + buildId で /api/v2/graphql を呼び出す

## 責務外

- ailead へのログイン認証が必要な非公開データの取得
- HLS 動画のダウンロード・変換
- 議事録の構造化（minutes-composer が担当）

## トリガー条件

- ユーザーが ailead の共有リンクを提示し、議事録作成やデータ取得を依頼した場合
- `dashboard.ailead.app/share/` を含む URL が提示された場合

## 前提

- dashboard.ailead.app の外部共有ページ（認証不要な公開共有リンク）が対象
- ailead の共有ページは SPA のため WebFetch では取得不可。GraphQL Persisted Query の解析による API 直接呼び出しが必要

## 重要な制約

- 認証が必要な非公開リンクには対応しない
- operationHash は事前解析済みの固定値を使用する。ailead 側の API 変更時は `references/api-spec.md` の更新が必要

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| ailead 共有 URL が引数で指定 | 非対話 | 自動でデータ取得を実行 |
| URL なし or 不正形式 | 対話 | ユーザーに URL を確認 |

## 取得可能なデータ

| データ種別 | 説明 |
|-----------|------|
| HLS 動画/音声 URL | `.m3u8` プレイリスト（Firebase Storage 上の `.ts` セグメント） |
| 文字起こし | 発話者名・テキスト・開始/終了時刻付きのセグメント群 |
| AI 会議要約 | トピック別要約・キーワード・カテゴリ分類 |
| 話者分離 | diarization データ（発話者・開始/終了時刻） |
| 参加者情報 | 名前・発言割合（talk ratio） |
| 会議メタデータ | タイトル・開始日時・所要時間・録画システム・共有期限 |

## 実行フロー

1. 共有 URL から share key を抽出する
2. HTML ページを取得し、`__NEXT_DATA__` から `buildId` を抽出する
3. [`references/api-spec.md`](references/api-spec.md) に記載の operationHash + buildId で GraphQL API を呼び出す
4. レスポンスをパースし、セッション作業領域の `workspace/` に保存する
5. minutes-composer へ引き渡すデータ（transcript.txt, metadata.json, summary.md, response.json）を `workspace/` に出力する

Python スクリプト: [`scripts/fetch/fetch_share.py`](scripts/fetch/fetch_share.py)

## 参照

| 用途 | ファイル |
|-----|---------|
| API 仕様 | [`references/api-spec.md`](references/api-spec.md) |
| 取得手順 | [`references/procedures.md`](references/procedures.md) |
| 環境構築 | [`references/setup.md`](references/setup.md) |
| 動作分岐検証 | [`evals/`](evals/) |
