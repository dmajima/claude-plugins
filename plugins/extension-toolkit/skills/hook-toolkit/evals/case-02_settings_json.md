# Case 02: settings.json への追加

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "プロジェクトの settings.json に Stop イベントの通知音を追加" |
| 引数 | `--scope project --event Stop --command "powershell -c \"[console]::beep(800,200)\"" --timeout 3` |
| フラグ | なし |
| 既存状態 | `<repo>/.claude/settings.json` 既存、`hooks` セクションは未定義 |

## 期待動作

### Phase 1: 配置先決定

`<repo>/.claude/settings.json` の `hooks.Stop` を配置先として確定。

### Phase 2: 既存 settings.json 読込

エンコーディング・改行コードを保持して読み込む。

### Phase 3: マージ書き戻し

既存エントリを破壊せず `hooks.Stop` に新エントリを追加。Python 経由で書き戻し（エンコーディング維持のため）。

### Phase 4: 検証

- 既存の他の設定（permissions、env 等）が無傷
- 新エントリが正しく挿入されている

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `<repo>/.claude/settings.json` |
| 標準出力 | 「settings.json に Stop フック追加」+ 再起動案内 |
| 終了状態 | 成功 |

## 分岐の根拠

`--scope project` 引数（settings.json 配置） である。
