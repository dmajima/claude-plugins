# projectboard references/

HUE ProjectBoard 操作スキルの詳細ドキュメントとスキル固有スクリプト。

## ファイル一覧

| パス | 用途 |
|------|------|
| [procedures.md](procedures.md) | 実行手順（入力解決 → 認証 → 読み取り / 構造解析 / 書き込みのコマンド例） |
| [setup.md](setup.md) | 環境構築（プラグイン共通 venv・機密ファイルの後始末） |
| [api-spec.md](api-spec.md) | 読み取り API 仕様（SSOT。認証・urlKey 変換・エンドポイント・データ構造） |
| [api-write.md](api-write.md) | 書き込み API 仕様（SSOT・確証度付き。WebSocket+STOMP・ボディ仕様・検証手順） |
| [pitfalls.md](pitfalls.md) | 既知の落とし穴（SPA フォールバック・CSRF・単位系等） |
| [scripts/](scripts/) | スキル固有スクリプト（auth / fetch / resolve / write / format / cleanup） |

## 利用ルール

- API 仕様の変更は api-spec.md / api-write.md（SSOT）のみを更新する（他ドキュメントへ重複転記しない）
- 認証値は環境変数（`PB_TENANT` / `PB_EMAIL` / `PB_PASSWORD`）で受け渡し、スクリプトは credentials.json を直接読まない
- 書き込みは必ず `scripts/write/stomp_session.py` 経由（生きた WebSocket 接続が必須）で行い、実行後に反映検証する
- 操作完了後は `scripts/cleanup/cleanup_sensitive.sh` で cookies.txt・取得 JSON を削除する
