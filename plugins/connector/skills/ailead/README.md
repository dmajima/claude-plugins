# ailead Connector

ailead の外部共有リンクから会議データを取得するコネクタスキル。

## このドキュメントについて

このファイルは人間向けリファレンスです。Claude の動作では使用されません。
Claude が参照するのは `SKILL.md` および `references/` 配下のファイルです。

## 使い方

### トリガーフレーズ例

```
ailead の共有リンクからデータを取得して
https://dashboard.ailead.app/share/GCsCUNU4G4s1UxUxloJ0CQbapqQ5hGrai_aAlEP2VXA
```

```
/connector:ailead-read https://dashboard.ailead.app/share/abc123
```

### 入力 → 出力の流れ

1. ailead 共有URL を入力
2. GraphQL API 経由でデータ取得
3. 以下のファイルがセッション作業領域に出力される:
   - `transcript.txt` — 文字起こし全文
   - `summary.md` — AI会議要約
   - `metadata.json` — 会議メタデータ
   - `response.json` — API レスポンス全文

## 動作例

### 入力

```
ailead のこの共有リンクからデータを取得して
https://dashboard.ailead.app/share/GCsCUNU4G4s1UxUxloJ0CQbapqQ5hGrai_aAlEP2VXA
```

### 出力ファイル

```
.claude/.local/work/20260616_01_ailead_fetch/
├── workspace/
│   ├── response.json      # GraphQL レスポンス全文
│   ├── transcript.txt     # [00:01:23 - 00:01:45] 山田: こんにちは...
│   ├── summary.md         # # 会議要約 ## 概要 ...
│   └── metadata.json      # {"title": "...", "duration": 3600, ...}
```

## カスタマイズ・拡張

### operationHash の更新

ailead がデプロイ更新されると `operationHash` が変わる場合がある。
スクリプトは自動フォールバック（JS チャンクから再抽出）するが、
既知ハッシュを更新したい場合:

1. `scripts/fetch/fetch_share.py` の `KNOWN_HASHES` リストを更新
2. `references/api-spec.md` セクション7の表を更新

### 依存パッケージの追加

`scripts/setup/requirements.txt` にパッケージを追加し、`setup_venv.sh` で再構築。

## ファイル構成

```
skills/ailead/
├── SKILL.md                          # スキル定義（Claude実行用）
├── README.md                         # 人間向けリファレンス（本ファイル）
├── references/
│   ├── api-spec.md                   # ailead API 仕様
│   ├── procedures.md                 # 実行手順
│   └── setup.md                      # 環境構築手順
├── scripts/
│   ├── setup/
│   │   ├── setup_venv.sh             # venv 構築
│   │   ├── teardown_venv.sh          # venv 削除
│   │   └── requirements.txt          # 依存パッケージ
│   └── fetch/
│       └── fetch_share.py            # データ取得スクリプト
└── evals/
    ├── case-01_share_fetch_success.md # 正常系
    ├── case-02_hash_outdated.md       # operationHash 更新
    ├── case-03_expired_link.md        # 期限切れリンク
    ├── case-04_no_url.md              # URL なし（対話モード）
    ├── case-05_empty_transcript.md    # 文字起こし未完了
    ├── case-06_password_protected.md  # パスワード保護リンク
    └── case-07_invalid_url.md         # 不正URL形式
```
