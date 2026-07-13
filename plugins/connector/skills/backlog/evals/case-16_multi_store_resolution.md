# Case 16: 複数ストアの優先順位解決（リポジトリ内ストアに無く従来パスにある）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Backlog で PROJ-123 を取得して"（対象スペースは `example.backlog.jp`） |
| フラグ | なし（対話モード） |
| 既存状態 | リポジトリ内で作業中（`.git` あり）。`<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` は存在するが Backlog 用エントリなし（別サービスのエントリのみ）。`~/.claude/.local/plugins/credentials-manager/credentials.json` は不在。`~/.claude/credentials.json` に `domains: ["example.backlog.jp"]` のエントリあり（`value` 非空） |

## 期待動作

### Phase 1: ストアの列挙と記載順の照合

- credentials-precheck.md セクション 2.1 の順序でストアを列挙する（本ケースでは順 1 と順 3 の 2 ストアが存在）
- `cred_lookup.sh --domain example.backlog.jp` 相当の照合を行う:
  - 順 1（リポジトリ内ストア）: `domains` 合致エントリなし → 次のストアへ（**ここで対話取得フォールバックに落ちない**）
  - 順 3（`~/.claude/credentials.json`）: 合致エントリあり → **このエントリの API キーを採用**

### Phase 2: 続行

- 採用したキーで Step 2（操作種別判定）以降へ続行し、課題取得を完遂する
- 対話取得フォールバック（セクション 4）は発動しない（解決順序 2 で解決済みのため）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | 課題 `PROJ-123` の取得結果（認証情報の確認質問は発生しない） |
| 終了状態 | 正常完了 |

## 分岐の根拠

credentials-precheck.md セクション 2.1: 「ストアを記載順にすべて照合し、最初に合致したエントリを採用」。先頭ストアに対象エントリが無いことは解決失敗ではなく、後続ストアの照合に進む。credentials-manager の保存先と従来の共有パスが別ファイルであっても、どちらに登録されたエントリでも見落とさないことを確認する。

## 関連ケース

- `case-01_issue_get.md`（単一ストアで解決する基本形）
- `case-05_credentials_missing.md`（全ストアで解決できず対話取得フォールバックに進む対比）
