# Case 12: サブエージェント呼び出しでのエラー時マニフェスト返却

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他プラグインが `Agent()` ツールで起動。PR URL: `https://tfs.unknown.com/.../pullrequest/999` |
| 引数 | 存在しないホストの PR URL + 出力ディレクトリ |
| フラグ | なし |
| 既存状態 | `tfs.unknown.com` は credentials.json の `tfs-password.domains` に未登録（credentials.json 自体が存在しない場合も同一の分岐） |

## 期待動作

1. サブエージェント内で `Skill(skill: "connector:azure")` を実行
2. 認証事前確認で `tfs.unknown.com` が未登録と判明（credentials-precheck.md セクション 1 の解決順序 1〜2 で解決不可）
3. サブエージェント実行（`AskUserQuestion` 利用不可）のため、ユーザーへの質問・対話取得フォールバックを試みない（同セクション 5）
4. API を 1 件も呼ばず、エラーマニフェスト JSON を返却する: `{"status":"error","error":"credentials_missing","service":"azure-tfs","detail":"tfs.unknown.com は credentials.json に未登録"}`
5. 呼び出し元はマニフェストを受領し、subagent-protocol.md セクション 3.5 の復帰手順（メインコンテキストでの対話取得 → 保存 → 再起動）を実行できる

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 返却値 | JSON マニフェスト（`status=error` / `error=credentials_missing` / `service=azure-tfs`） |
| 終了状態 | エラー。呼び出し元がセクション 3.5 の復帰手順で構造的にリカバリ可能 |

## 分岐の根拠

サブエージェントプロトコルのエラー系分岐。認証情報が解決できない場合も標準エラー種別 `credentials_missing`（subagent-protocol.md セクション 3.3）のマニフェスト形式で返し、呼び出し元が復帰手順（同セクション 3.5）へ機械的に接続できることを確認する。

## 関連ケース

- `case-11_subagent_read_pr.md`（正常系）
- `case-05_unregistered_host.md`（同じ未登録ホストでもメインコンテキストでは対話取得フォールバックに進む対比）
