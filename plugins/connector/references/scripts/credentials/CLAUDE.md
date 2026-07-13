# connector references/scripts/credentials/

認証情報ストア（credentials.json）の照合・保存スクリプト。仕様の SSOT は [../../credentials-precheck.md](../../credentials-precheck.md)（セクション 2.1 / 4.5）。

## 目的と範囲

複数ストア（credentials-manager の保存先 2 箇所 + 従来の共有パス）の横断照合と、対話取得フォールバック「保存する」時の安全な保存を実装する。

## ファイル一覧

| ファイル | 用途 |
|---------|------|
| [cred_lookup.sh](cred_lookup.sh) | ストア列挙（`--list-stores`）/ `domains` 照合（`--domain`）/ エントリ名照合（`--entry` + `--field`）。未解決は exit 1 |
| [cred_save.sh](cred_save.sh) | 保存先決定（誘導ガード付き）+ jq マージ書き込み（引数: entry-name / entry-file） |

## 利用ルール

- 値は標準出力にのみ返る。会話・ログへの転記はマスク必須（credentials-precheck.md セクション 4.3）
- `cred_save.sh` はユーザーが「入力して続行（保存する）」を明示選択した場合のみ呼び出す
- リポジトリ内ストアへの保存は同名エントリの更新 + `.gitignore` 検証通過時のみ（新規エントリはホーム側限定・シンボリックリンク拒否）
- 出所不明のリポジトリを開いた状態で認証操作を行わない（credentials-precheck.md セクション 7）
