# C# レビュー観点プロファイル — security details

`csharp.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `csharp.md`（hub）に残置。
本ファイルは観点 3.7 を収録。

### 3.7 セキュリティ【担当: security-engineer】

> **埋め込み SQL の横断適用**: `SqlCommand.CommandText` / `ExecuteReader` / Dapper の生 SQL 等でコードに埋め込まれた SQL 文字列には、インジェクション以外にも `${CLAUDE_PLUGIN_ROOT}/references/languages/sql.md` の観点（`SELECT *`・`NOLOCK`・列非明示・NULL 三値論理・方言固有）を併用適用する（`.sql` ファイルが差分に無くても適用。language-detection.md Step 4）。

- [ ] SQL 文字列連結（SQL インジェクション → パラメタライズドクエリ / ORM）
- [ ] パス結合の検証漏れ（`Path.Combine` + 相対パス遡り → path traversal）
- [ ] `BinaryFormatter` 等の危険なデシリアライザ使用
- [ ] 乱数に `Random` を使用（セキュリティ用途は `RandomNumberGenerator`）
- [ ] 機密情報（接続文字列・API キー）のハードコード・ログ出力
- [ ] `ProcessStartInfo` / `Process.Start` へのユーザー入力の未検証受け渡し（コマンドインジェクション）
- [ ] 証明書検証の無効化（`ServerCertificateCustomValidationCallback` で常に true 等）

