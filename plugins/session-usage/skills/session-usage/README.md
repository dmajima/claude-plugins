# session-usage スキル

このディレクトリは `session-usage` プラグインの実作業スキル本体である。
本 README は人間向けリファレンスであり、Claude スキルの動作では使用されない。

## 役割

- カレントセッション（または指定 UUID）の JSONL から `message.usage` を集計
- 整形済み文字列を生成（`/doctor` 風の罫線レイアウト）
- 整形済み文字列を Claude UI に表示しつつ、クリップボードへ自動コピー
- `AskUserQuestion` で「再集計 / 終了」の対話ループを提供

呼び出し元コマンド（`commands/session-usage.md`）が引数解釈とトリガー判定を担当し、
本スキルが集計・表示・コピー・対話処理を担当する責務分離。

## ファイル構成

```
skills/session-usage/
├── SKILL.md                        # スキル定義（Claude が読む）
├── README.md                       # 本ファイル（人間向け）
├── scripts/
│   └── aggregate/
│       └── aggregate.sh           # JSONL 集計+整形+クリップボードコピー
└── references/
    └── procedures.md               # 実行手順詳細
```

## 拡張・カスタマイズ

### 表示項目を増やす

`scripts/aggregate/aggregate.sh` の整形済み文字列モード（末尾）に行を追加する。
集計値のフィールド構造は `-AsObject` 出力（`Totals` / `ByModel` / `GrandTotal`）に
従う。

### 対話選択肢を増やす

呼び出し元（Claude）が `AskUserQuestion` のオプションを増やせばよい。
スキル側で固定する必要はない。例: 「CSV エクスポート」を追加する場合は
`aggregate.sh` に `-AsCsv` を追加し、`AskUserQuestion` のオプションに加える。

## 動作確認方法

### スキルとして

```
/session-usage
```

### スクリプト直接実行（開発時）

```bash
# 整形済み文字列を表示+コピー
bash scripts/aggregate/aggregate.sh --stdout --copy

# 整形済み文字列を変数で取得
rendered=$(bash scripts/aggregate/aggregate.sh --stdout)

# JSON 形式で取得
bash scripts/aggregate/aggregate.sh --as-object | jq .
```
## 既知の制限

- Windows 専用（`Set-Clipboard` が前提）
- 対話は `AskUserQuestion` に集約

## ライセンス

プラグインルート（`plugins/session-usage/LICENSE`）の MIT に従う。
