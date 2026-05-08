# Case 26: 編集（update、対話モードで差分確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "openai-api-key の値を新しいキー sk-newvalue1234567890 に更新して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `openai-api-key`（value=`sk-old1234567890abcdef`）が存在 |

## 期待動作

### Phase 1: パス解決と読み込み

- 解決パスから `credentials.json` を読み込み
- `openai-api-key` の存在を確認

### Phase 2: 変更フィールド特定

- ユーザ発話から `value` 変更と判定
- 他フィールド（`urls` / `domains` / `auth_method` / `description` / `type`）は変更しない

### Phase 3: 差分提示と確認

- マスク済みで変更前/変更後を提示:
  - `value: sk-o****cdef → sk-n****7890`
- `AskUserQuestion` で「更新する／キャンセル」を確認

### Phase 4: 書き戻し

- 承諾時のみ書き戻し
- `updated_at` を現在時刻で更新（`created_at` は維持）

### Phase 5: 完了通知

- 変更フィールドのみ通知（未変更フィールドは省略）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `credentials.json`（該当エントリ更新） |
| 標準出力（要約） | "Updated credential 'openai-api-key': value: sk-o****cdef → sk-n****7890" |
| 終了状態 | 成功 |

## 分岐の根拠

「編集（update）+ 対話モード」分岐。差分のマスク表示と部分更新（特定フィールドのみ）を検証する。

## 関連ケース

- `case-01_save_with_url.md`（新規保存との対比）
- `case-27_manage_command.md`（コマンド経由での編集）
