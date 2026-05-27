# ailead-fetcher

ailead の外部共有リンクから動画・音声・文字起こし・AI会議要約を GraphQL API 経由で取得するスキル。

## このドキュメントについて

本ファイルは人間向けリファレンスであり、Claude の動作では使用されない。

## 使い方

ailead の共有リンク（`dashboard.ailead.app/share/...`）を提示して議事録作成やデータ取得を依頼する。

```
ailead の共有リンク https://dashboard.ailead.app/share/xxxxx から議事録を作成して
```

認証不要な公開共有リンクのみ対応。非公開リンクには対応しない。

## 処理の流れ

1. 共有 URL から share key を抽出
2. HTML から `buildId` を取得
3. 事前解析済みの operationHash + buildId で GraphQL API を呼び出し
4. transcript.txt / metadata.json / response.json をセッション作業領域に出力

## ファイル構成

```
ailead-fetcher/
├── SKILL.md
├── README.md
├── references/
│   ├── api-spec.md          # GraphQL API 仕様（operationHash 等）
│   ├── procedures.md        # 取得手順
│   └── setup.md             # 環境構築
└── scripts/
    └── fetch/
        └── fetch_share.py   # データ取得スクリプト
```
