# Case 02: minutes.json 不在エラー

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | Markdown 出力を依頼されたが、前段の minutes-composer が未実行 |
| 前提ファイル | `workspace/minutes.json` が存在しない |
| 状態 | `workspace/` ディレクトリは存在するが `minutes.json` が含まれていない |

## 期待動作

1. `workspace/minutes.json` の存在を確認する
2. ファイルが存在しないことを検出する
3. ユーザーにエラーを報告する:
   - `minutes.json` が見つからないこと
   - `minutes-composer` が未実行である可能性が高いこと
   - 先に `minutes-composer` でデータを構造化する必要があること
4. Python スクリプトを実行しない（入力がないため）
5. 必要に応じて `minutes-composer` の起動を提案する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（エラーのため出力しない） |
| ユーザーへの通知 | 「`workspace/minutes.json` が見つかりません。先に `minutes-composer` で議事録データを構造化してください。」等のエラーメッセージ |
| 次のアクション提案 | 「`meeting-minutes:minutes-composer` を先に実行しますか？」等の提案 |
| 終了状態 | エラー終了（ユーザーに原因と対処を明示） |

## 分岐の根拠

SKILL.md「前提」: 「minutes-composer が出力した minutes.json がセッション作業領域の workspace/ に存在すること」。この前提が満たされない場合のエラーパス。`references/procedures.md` トラブルシューティング表: 「minutes.json が見つからない → workspace/minutes.json の存在を確認。minutes-composer が完了しているか確認」。

## 関連ケース

- `case-01_normal.md`（minutes.json が存在する正常パス）
