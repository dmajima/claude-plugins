# Case 15: サブエージェント呼び出しで認証情報なし（credentials_missing マニフェスト返却）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他プラグインが subagent-protocol.md のテンプレートに従い `Agent()` で起動。args: `読み取りのみ。OTHER-1 の件名・本文・コメントを取得して` + 出力ディレクトリ + マニフェスト返却指示 |
| 引数 | 課題キー `OTHER-1`（対象スペース `otherspace.backlog.jp`） |
| フラグ | なし |
| 既存状態 | credentials-manager プラグイン未導入。`~/.claude/credentials.json` が存在しない（またはエントリ・`domains` 不一致） |

## 期待動作

### Phase 1: サブエージェント内の認証事前確認

1. サブエージェント内で `Skill(skill: "connector:backlog")` を実行する
2. credentials-precheck.md セクション 1 の解決順序 1〜2 で解決不可と判定する
3. サブエージェント実行（`AskUserQuestion` 利用不可）のため、解決順序 3b（セクション 5）を適用する

### Phase 2: エラーマニフェスト返却

- **ユーザーへの質問を試みない**（対話取得フォールバックはサブエージェント内では実行不可）
- **API を 1 件も呼ばない**
- 以下のエラーマニフェストのみを返して終了する:

```json
{
  "status": "error",
  "error": "credentials_missing",
  "service": "backlog",
  "detail": "credentials.json に otherspace.backlog.jp 用エントリなし"
}
```

### Phase 3: 呼び出し元の復帰（subagent-protocol.md セクション 3.5）

- 呼び出し元（メインコンテキスト）はマニフェストを受領し、credentials-precheck.md セクション 4 の対話取得フォールバックをメインコンテキストで実施する
- ユーザーが「入力して続行（保存する）」を選択 → credentials.json 保存 → 同一テンプレートでサブエージェントを再起動 → 課題取得が完遂される
- ユーザーが「中止」を選択 → 呼び出し元のフロー側でエラーとして処理する（黙って終了しない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | サブエージェント初回: なし（issue.json は書き出されない） |
| 返却値 | JSON マニフェスト（`status=error` / `error=credentials_missing` / `service=backlog`） |
| 終了状態 | 呼び出し元が復帰手順を実行可能（再起動後に success マニフェスト + `issue.json`） |

## 分岐の根拠

サブエージェント実行時は `AskUserQuestion` が利用できないため、対話取得フォールバック（3a）ではなくエラーマニフェスト返却（3b）に分岐する（credentials-precheck.md セクション 1 の実行コンテキスト判定）。構造化エラー + 呼び出し元の対話復帰の 2 段構えにより、credentials-manager / credentials.json 不在の環境でもサブエージェント方式の呼び出しが完遂できることを確認する。

## 関連ケース

- `case-05_credentials_missing.md`（同じ認証情報なしでもメインコンテキストでは対話取得フォールバックに進む対比）
- `case-09_delegation_read.md`（認証情報が揃っている委譲読み取りの正常系）
