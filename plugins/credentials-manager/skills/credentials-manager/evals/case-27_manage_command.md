# Case 27: /credentials-manager:manage コマンド経由での管理操作

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `/credentials-manager:manage` |
| 引数 | なし（対話メニューで選択） |
| フラグ | なし |
| 既存状態 | `credentials.json` に既存エントリあり |

## 期待動作

### Phase 1: コマンド起動 → メニュー UI

- `commands/manage.md` のプロンプトに従い、`AskUserQuestion` で操作メニューを提示:
  - 一覧表示
  - 追加
  - 編集
  - 削除
  - 終了

### Phase 2: ユーザ選択 → スキル委譲

| ユーザ選択 | 動作 |
|----------|------|
| 一覧表示 | `credentials-reader` を起動して list を実行 |
| 追加 | `credentials-manager` の save フローを起動 |
| 編集 | `credentials-manager` の update フローを起動 |
| 削除 | `credentials-manager` の delete フローを起動 |
| 終了 | コマンドを終了 |

### Phase 3: 操作完了後

- 各操作完了後、メニューに戻り次操作を確認
- 「終了」が選択されるまで対話継続

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 操作内容に応じた `credentials.json` の更新 |
| 標準出力（要約） | メニュー UI の遷移ログ + 各操作の完了通知 |
| 終了状態 | 成功（ユーザが「終了」を選択） |

## 分岐の根拠

「コマンド経由でのメニューUI管理」フロー。reader / manager が責務に応じて使い分けられること、AskUserQuestion ベースの設定 UI が成立することを検証する。

## 関連ケース

- `case-01_save_with_url.md`（直接呼び出しでの save）
- `case-26_update_with_confirm.md`（直接呼び出しでの update）
- `case-07_delete_with_confirm.md`（直接呼び出しでの delete）
- `credentials-reader:case-06_list_credentials.md`（list 委譲先）
