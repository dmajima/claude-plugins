# Python レビュー観点プロファイル — security details

`python.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `python.md`（hub）に残置。
本ファイルは観点 3.7 を収録。

### 3.7 セキュリティ【担当: security-engineer】

> **埋め込み SQL の横断適用**: `cursor.execute(...)` / `pyodbc` / `sqlite3` / SQLAlchemy の `text()` 等でコードに埋め込まれた SQL 文字列には、インジェクション以外にも `${CLAUDE_PLUGIN_ROOT}/references/languages/sql.md` の観点（`SELECT *`・列非明示・NULL 三値論理・方言固有）を併用適用する（`.sql` ファイルが差分に無くても適用。language-detection.md Step 4）。

- [ ] **SQL 文字列組み立て**（f-string / `%` / `.format()` / `+` 連結でユーザー入力を SQL に埋め込み → SQL インジェクション。パラメタライズドクエリ / ORM へ）
- [ ] **`eval` / `exec` / `compile`** へのユーザー入力受け渡し（任意コード実行）
- [ ] **`pickle.loads` / `yaml.load`（Loader 未指定）/ `marshal`** で信頼できないデータをデシリアライズ（`yaml.safe_load` へ）
- [ ] **`subprocess` の `shell=True`** + ユーザー入力（コマンドインジェクション → 引数配列 + `shell=False`）
- [ ] パス結合の検証漏れ（`os.path.join` / `Path` + ユーザー入力 → path traversal。`tarfile.extractall` の zip/tar 展開先検証）
- [ ] 乱数の用途（トークン・パスワード・秘密鍵に `random` → `secrets` モジュール）
- [ ] 機密情報（API キー・接続文字列・パスワード）のハードコード・ログ出力
- [ ] `requests` / TLS での `verify=False`（証明書検証の無効化）
- [ ] XML パース（`xml.etree` / `lxml`）での外部エンティティ・DTD 展開（XXE → `defusedxml`）
- [ ] 一時ファイルの安全な生成（`tempfile.mktemp` の TOCTOU レース → `NamedTemporaryFile` / `mkstemp`）
- [ ] Web フレームワークの `debug` 有効化・ハードコード `SECRET_KEY` の本番残留（詳細は frameworks/python-web.md 参照）

