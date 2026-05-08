# セキュリティ注意（書き込み系）

`credentials-manager` スキルが守るべき・利用者に伝えるべきセキュリティ上の制約。参照系の制約は `../../credentials-reader/references/security.md` を参照すること。

## 1. 平文保存

| 項目 | 内容 |
|-----|------|
| 保存形式 | JSON 平文（暗号化なし） |
| 想定用途 | 個人開発・ローカル開発環境での利便性向上 |
| 非対象 | 本番秘匿情報・規制対象データ・監査要件のあるシステム |

本番秘匿情報には外部 secret manager（AWS Secrets Manager / HashiCorp Vault / 1Password 等）を用いること。本スキルはあくまで Claude Code セッションの利便性向上を目的とする。

## 2. 値の表示制約

| 場面 | 表示 |
|-----|------|
| ユーザへの会話出力 | マスク済み値（`<先頭4>****<末尾4>`）のみ |
| ログ・コミットメッセージ | フル値・マスク済み値ともに含めない |
| プログラム利用（API 呼び出し時） | 本スキルの書き込みフローでは利用しない（参照系は `credentials-reader`） |
| `update` 時の差分表示 | 変更前 / 変更後ともにマスク表示 |

8 文字以下の短い値は部分露出せず全マスク `****` とする。

## 3. リポジトリへの混入防止

| 項目 | 動作 |
|-----|------|
| `credentials.json` のコミット | 禁止 |
| `.claude/.local/` の `.gitignore` 登録 | リポジトリ内保存時は **必須確認**（書き込み前に検証） |
| `.gitignore` 未登録時 | ユーザに警告し、登録を提案してから書き込む |
| `credentials.json.bak.*` バックアップファイルのコミット | 禁止（同 `.gitignore` 配下に置かれる） |

## 4. 引き継ぎ時の取り扱い

`credentials-reader` から引き継がれた場合（[`../../credentials-reader/references/handoff.md`](../../credentials-reader/references/handoff.md)）:

| 渡される情報 | 取り扱い |
|------------|--------|
| 候補名（推定） | 既定値として `AskUserQuestion` で確認 |
| マスク済み値 | 確認表示のみ。書き込みには **ユーザ再入力のフル値** を使用 |
| 推定 `domains` / `urls` / `auth_method` | 既定値として提示、ユーザ確認後に確定 |
| **フル値** | 渡されない。reader 側はマスク化のみを引き渡し、ユーザに再入力を求める |

## 5. 削除・修復時の注意

| 操作 | 注意事項 |
|-----|--------|
| `delete` | ファイルからエントリを除去するだけであり、ディスク上の物理削除は行わない（OS レベル対応はユーザの責任） |
| `repair` | 破損ファイルは必ず `credentials.json.bak.{timestamp}` にバックアップしてから再初期化する。バックアップを上書きしない |
| バックアップの寿命 | ユーザが手動で削除する。本スキルは古いバックアップの自動削除を行わない |

## 6. 利用者への注意喚起

新規保存時に以下の旨を一度通知する（同一セッション内では繰り返さない）:

```
[credentials-manager] Note: credentials are stored as plain text in <path>.
Suitable for local development; not for production secrets.
```

`update` / `delete` / `repair` 操作時は、対象認証情報の **マスク済み値・名前・更新日時** を表示してユーザの誤操作を防ぐ。

## 7. グローバル設定との関係

| 設定 | 影響 |
|-----|------|
| `~/.claude/rules/security/credentials-management.md` | 存在すればグローバルに認証情報問い合わせ先として参照される。**不在でも本プラグインの description / フックで起動するため、利用者環境に同ルールがある必要はない** |
| `~/.claude/credentials.json`（旧仕様） | 利用しない（パス解決ルールに基づき `~/.claude/.local/plugins/credentials-manager/credentials.json` を利用） |
