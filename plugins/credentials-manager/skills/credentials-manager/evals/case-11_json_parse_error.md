# Case 11: JSON 破損時の修復（repair、credentials-reader 引き継ぎ受け入れ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動契機 | `credentials-reader` が一覧表示・取得の途中で JSON パース失敗を検知し、修復承諾後に本スキルを `repair` モードで起動 |
| 引数 | `repair`（または非対話モード時は `--non-interactive --repair`） |
| フラグ | なし |
| 既存状態 | `credentials.json` が破損（不正 JSON）。例: `{"credentials": {`（途中で切れている） |

## 期待動作

### Phase 1: 引き継ぎ受け入れ

- `credentials-reader` から `repair` モードで起動されたことを認識
- パス解決 → 破損ファイルの存在確認

### Phase 2: バックアップ作成

- 破損ファイルを `credentials.json.bak.{ISO8601タイムスタンプ}` にコピー
- ユーザに「`credentials.json` が破損していました。バックアップを `<bak-path>` に保存します」と通知
- 対話モード時は再初期化前にユーザ確認、非対話モードはそのまま続行

### Phase 3: 空ストア再初期化

- `credentials.json` を `{"credentials": {}}` で書き戻し
- 再初期化完了を通知

### Phase 4: 制御を `credentials-reader` に戻す

- 本スキルは修復のみで完了
- 元の参照操作（一覧表示・取得等）は呼び出し元 reader が再試行

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `credentials.json`（空ストア） + `credentials.json.bak.{timestamp}`（バックアップ） |
| 標準出力（要約） | 破損通知 + バックアップパス + 空ストア再初期化通知 |
| 終了状態 | 成功（破損リカバリ後） |

## 分岐の根拠

「修復（repair）+ reader からの引き継ぎ受け入れ」分岐に該当（`references/operations.md` 節 5）。データ消失防止のためバックアップ → 再初期化の順序が必須。reader 単体では書き込みを行わないため manager 側で完結する責務分離を検証する。

## 関連ケース

- `credentials-reader:case-10_json_parse_error.md`（reader 側の引き継ぎ提案フロー）
- `case-08_non_interactive.md`（非対話モードでの確認スキップ動作）
