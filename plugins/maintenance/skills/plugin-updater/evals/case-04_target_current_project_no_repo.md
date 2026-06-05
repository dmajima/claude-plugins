# Case 04: target=current-project + git リポジトリ外のエラーケース

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update` コマンド経由（target=current-project を委譲） |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `current-project` |
| 既存状態 | git リポジトリ外のディレクトリで実行（`.git` ディレクトリが存在しない） |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `target` を `current-project` と確定（ホワイトリスト一致）

### Phase A-0-2: Claude Code CLI 存在チェック
- CLI の存在は確認される（エラーの原因ではない）

### Phase A-Repo: git リポジトリ存在確認（current-project 専用チェック）
- `target=current-project` の場合、Phase A の対象収集前に現在のディレクトリが git リポジトリ内か確認する
- カレントディレクトリから上位に向かって `.git` ディレクトリを探索する
- `.git` ディレクトリが見つからない場合 → **エラー中断**
- 以下のエラーメッセージを出力して Phase A 以降の処理を行わず即終了:

```text
エラー: target=current-project が指定されましたが、git リポジトリ外のため Project / Local スコープを処理できません。
全プロジェクトのプラグインを更新したい場合は /update-all を使用してください。
```

### Phase A〜G: 実行されない
- CLI 呼び出しなし
- 設定ファイルの Read なし

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | なし |
| 標準出力（要約） | SSOT エラーフォーマット（`output-formats.md`「git リポジトリ外で target=current-project 指定時」参照） |
| 終了状態 | エラー終了（exit ≠ 0） |

## 分岐の根拠

このケースが分岐するトリガーは `target = current-project` かつ git リポジトリ外での起動 である（ADR-PU-015）。
`target=current-project` は「現在の git リポジトリの project/local プラグインのみを更新する」という意味であるため、
git リポジトリ外での実行は前提条件を満たさずエラーとなる。

## 関連ケース

- `case-02_target_current_project.md`（target=current-project + git リポジトリ内の正常系）
- `case-06_invalid_target.md`（A-0-1 バリデーション失敗）
- ADR-PU-015: `target` パラメータの導入（current-project の事前条件定義）