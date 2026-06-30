# Case 12: サブエージェント呼び出しでのエラー時マニフェスト返却

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他プラグインが `Agent()` ツールで起動。PR URL: `https://tfs.unknown.com/.../pullrequest/999` |
| 引数 | 存在しないホストの PR URL + 出力ディレクトリ |
| フラグ | なし |
| 既存状態 | `tfs.unknown.com` は credentials.json の `tfs-password.domains` に未登録 |

## 期待動作

1. サブエージェント内で `Skill(skill: "connector:azure")` を実行
2. 認証事前確認で `tfs.unknown.com` が未登録と判明
3. エラーマニフェスト JSON を返却: `{"status":"error","error":"AUTH_NOT_FOUND","detail":"tfs.unknown.com は credentials.json に未登録"}`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 返却値 | JSON マニフェスト（status=error） |
| 終了状態 | エラー。呼び出し元がエラーハンドリング可能 |

## 分岐の根拠

サブエージェントプロトコルのエラー系分岐。認証失敗時にもマニフェスト形式でエラーを返し、呼び出し元が構造的にエラーを処理できることを確認する。

## 関連ケース

- `case-11_subagent_read_pr.md`（正常系）
