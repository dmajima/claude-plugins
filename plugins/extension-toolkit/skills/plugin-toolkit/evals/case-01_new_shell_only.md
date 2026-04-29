# Case 01: 新規外形のみ作成

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新しいプラグイン `dev-toolkit` を作って" |
| 引数 | `dev-toolkit` |
| フラグ | なし |
| 既存状態 | `dev-toolkit` プラグインが未存在 |

## 期待動作

### Phase 1: パラメータ確認

ユーザに以下を確認:

- 1 行説明
- 作者名
- 含めるアイテム種別（commands / skills / agents / hooks / mcp）

### Phase 2: 命名衝突チェック

`plugins/dev-toolkit/` の存在を確認。未存在なので新規作成へ進行。

### Phase 3: 外形生成

`templates/plugin/` をコピー、プレースホルダ置換。指定されたサブディレクトリのみ作成。

### Phase 4: 検証

- plugin.json valid
- name = ディレクトリ名
- README にプレースホルダ残存なし

### Phase 5: 引き渡し

生成ファイル一覧と、後続のスキル/コマンド/フック作成のための接続先（`skill-toolkit` 等）を提示。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/.claude-plugin/plugin.json` `README.md` + 指定サブディレクトリ |
| 標準出力（要約） | 「`dev-toolkit` プラグイン外形を作成」+ 中身追加の案内 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは移管対象の指定なし である。
