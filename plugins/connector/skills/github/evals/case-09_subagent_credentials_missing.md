# Case 09: サブエージェント呼び出しで gh CLI 未認証（credentials_missing マニフェスト返却）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他プラグインが subagent-protocol.md のテンプレートに従い `Agent()` で起動。args: `読み取りのみ。PR URL: https://github.com/contoso/webapp/pull/42 の PR メタ情報を取得して` + 出力ディレクトリ + マニフェスト返却指示 |
| 既存状態 | `gh auth status` が終了コード != 0（未認証。`GH_TOKEN` / `GITHUB_TOKEN` も未設定） |

## 期待動作

1. サブエージェント内で `Skill(skill: "connector:github")` を実行する
2. Step 1 の認証確認（`gh auth status`）で未認証を検出する
3. サブエージェント実行（`AskUserQuestion` 利用不可）のため、`gh auth login` の案内を試みない（credentials-precheck.md セクション 5）
4. API を 1 件も呼ばず、以下のエラーマニフェストのみを返して終了する:

```json
{
  "status": "error",
  "error": "credentials_missing",
  "service": "github",
  "detail": "gh CLI 未認証（gh auth status が非 0）"
}
```

5. 呼び出し元は subagent-protocol.md セクション 3.5 に従い、メインコンテキストで `gh auth login` の実行をユーザーに案内し、認証確立後に同一テンプレートで再起動する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（pr-meta.json は書き出されない） |
| 返却値 | JSON マニフェスト（`status=error` / `error=credentials_missing` / `service=github`） |
| 終了状態 | 呼び出し元が復帰手順を実行可能（認証確立 → 再起動後に success マニフェスト） |

## 分岐の根拠

サブエージェント実行時は対話（認証確立の案内 → 再確認）が実行できないため、エラーマニフェスト返却（credentials-precheck.md セクション 1 の 3b）に分岐する。GitHub 認証は gh CLI 管理のため credentials.json への保存では復帰せず、呼び出し元がメインコンテキストで `gh auth login` を案内する点が他スキルと異なる。

## 関連ケース

- `case-04_auth_failure.md`（同じ未認証でもメインコンテキストでは案内 → 再確認 → 続行する対比）
- `case-08_subagent_read_pr.md`（認証済みのサブエージェント正常系）
