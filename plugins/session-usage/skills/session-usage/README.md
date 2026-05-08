# session-usage スキル

このディレクトリは `session-usage` プラグインの実作業スキル本体である。
本 README は人間向けリファレンスであり、Claude スキルの動作では使用されない。

## 役割

- カレントセッション（または指定 UUID）の JSONL から `message.usage` を集計
- 整形済み文字列を生成（`/doctor` 風の罫線レイアウト）
- 対話 TUI を新規ウィンドウで起動（`c` / `r` / `q` のキー操作）

呼び出し元コマンド（`commands/session-usage.md`）が引数解釈とトリガー判定を担当し、
本スキルが集計・表示・対話処理を担当する責務分離。

## ファイル構成

```
skills/session-usage/
├── SKILL.md                        # スキル定義（Claude が読む）
├── README.md                       # 本ファイル（人間向け）
├── scripts/
│   ├── aggregate/
│   │   └── aggregate.ps1           # JSONL 集計と整形（純粋関数）
│   └── tui/
│       ├── tui.ps1                 # ReadKey ループ・再描画
│       └── launch.ps1              # 新規ウィンドウ起動
└── references/
    ├── procedures.md               # 実行手順詳細
    └── tui-spec.md                 # TUI 仕様（画面構成・キーバインド）
```

## 拡張・カスタマイズ

### 表示項目を増やす

`scripts/aggregate/aggregate.ps1` の整形済み文字列モード（末尾）に行を追加する。
集計値のフィールド構造は `-AsObject` 出力（`Totals` / `ByModel` / `GrandTotal`）に
従う。

### キーバインドを増やす

`scripts/tui/tui.ps1` のキーループ `switch ($key.KeyChar)` にケースを追加し、
フッター表示文字列（最終 Write-Host）も更新する。
仕様は `references/tui-spec.md` を併せて更新する。

### CSV / JSON エクスポートを追加

`aggregate.ps1` に `-AsCsv` / `-AsJson` パラメータを足し、`tui.ps1` のキーバインドに
`[e]` Export を追加する。エクスポート先は `~/.claude/.local/plugins/session-usage/`
配下に置く（`local-data-directory.md` 規約）。

## 動作確認方法

### スキルとして

```
/session-usage
```

別ウィンドウで TUI が起動する。

### スクリプト直接実行（開発時）

```powershell
# 整形済み文字列を取得
pwsh -File scripts/aggregate/aggregate.ps1

# 対話 TUI を現プロセスで起動（PowerShell 直接実行用）
pwsh -File scripts/tui/launch.ps1 -NoNewWindow

# オブジェクト形式で取得
pwsh -File scripts/aggregate/aggregate.ps1 -AsObject | ConvertTo-Json
```

## 既知の制限

- Windows 専用（`Set-Clipboard` が前提）
- PowerShell 7+ 必須（`#Requires -Version 7.0`）
- Claude Code Bash 経由では対話 TUI が動かないため、必ず別ウィンドウ起動

## ライセンス

プラグインルート（`plugins/session-usage/LICENSE`）の MIT に従う。
