# Case 07: シークレット混入検出時の fail-closed

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`my-plugin` を公開" |
| 引数 | `my-plugin --full-auto` |
| フラグ | `--full-auto` |
| 既存状態 | プラグイン実体内に `.env` ファイルあり、または内容に AWS アクセスキーパターンを含む |

## 期待動作

### Phase 1: プラグイン実体検証

`plugins/my-plugin/.claude-plugin/plugin.json` 存在確認後、**シークレット混入スキャン** を実行（[`../references/secret-scan.md`](../references/secret-scan.md) の検出パターンに従う）。

### Phase 2: 検出 → fail-closed

以下のいずれかを検出した場合、公開フローを **即時中断**:

| 検出種別 | 例 |
|---------|---|
| ファイル名パターン | `.env` / `*.pem` / `*.key` / `id_rsa` / `credentials.json` / `secrets.json` 等 |
| 内容パターン | `AKIA[0-9A-Z]{16}` / `ghp_[A-Za-z0-9]{36}` / `xox[baprs]-...` / `-----BEGIN ... PRIVATE KEY-----` 等 |
| Generic Password | `(password|secret|api[-_]?key)\s*[:=]\s*["']?[^"'\s]{8,}["']?` |

`--full-auto` でも例外なく中断する（fail-closed の優先度が最高）。

### Phase 3: ユーザへの提示

`AskUserQuestion` で以下を提示:

```text
シークレット混入の疑いを検出しました。公開フローを中断します。

検出ファイル:
- plugins/my-plugin/.env — filename:.env
- plugins/my-plugin/config/api.yaml:23 — content:aws_access_key

どう対応しますか？
1. 該当ファイルを削除/移動してから再実行
2. .gitignore に追加してから再実行
3. 誤検出として続行（ユーザ責任で実行、再確認を要求）
4. キャンセル
```

選択肢 3 は **二重確認**（"本当に公開してよいか？" の追加質問）を必ず行う。

### Phase 4: 選択分岐

| 選択 | 動作 |
|-----|------|
| 1 | 該当ファイル削除/移動を案内、本スキル終了（再実行待ち） |
| 2 | `.gitignore` 追加を案内、本スキル終了（再実行待ち） |
| 3 | 二重確認後に続行（フルオートでも本選択は対話必須） |
| 4 | 何もせず終了 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | なし（修正前にフロー中断） |
| 標準出力 | 検出ファイル一覧 + 選択肢提示 |
| 終了状態 | 中断（公開未完了） |
| Git 状態 | コミット・push・PR 作成なし |

## 分岐の根拠

シークレット検出 → fail-closed 動作。
`--full-auto` でもユーザ確認を強制する例外パスとして設計。

## 関連ケース

- `case-04_full_auto.md`（正常フロー、シークレット未検出）
- `case-06_full_auto_on_main_blocked.md`（保護ブランチ阻止、別の fail-closed パターン）
