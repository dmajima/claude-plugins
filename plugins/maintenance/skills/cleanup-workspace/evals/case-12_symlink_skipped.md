# Case 12: シンボリックリンク検出時のスキップ

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "古い作業フォルダを整理して" |
| 引数 | `--days 30 --dry-run` |
| フラグ | `--dry-run` |
| 既存状態 | `.claude/.local/work/` 配下に以下が混在<br>- `20250101_01_legit/`（通常ディレクトリ、30 日より古い）<br>- `20250101_99_fake/`（シンボリックリンク、リンク先は `C:/Windows/System32`） |

## 期待動作

### Phase 1: 対象収集
- `Get-ChildItem` で両方のエントリを取得

### Phase 2: バリデーション
- `20250101_01_legit/`: `Test-ValidSessionPath` で `$item.LinkType` が `$null` → 合格、候補に追加
- `20250101_99_fake/`: `Test-ValidSessionPath` で `$item.LinkType` が `SymbolicLink` → 不合格、Verbose ログに「Skipped (invalid)」記録
- リンク先（`C:/Windows/System32`）は **絶対に追従しない**

### Phase 3: 候補表示
- `20250101_01_legit/` のみ表示
- シンボリックリンクは表示されない

### Phase 4: ドライラン終了
- 実削除なし
- シンボリックリンク自身も削除されない（保持）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 削除実行 | なし |
| 標準出力（要約） | 「候補件数: 1 件」（fake は含まれない）+ Verbose ログにスキップ理由 |
| 終了状態 | 成功（exit 0） |
| シンボリックリンク状態 | 保持（変更なし） |
| リンク先（System32 等） | **絶対に変更されない** |

## 分岐の根拠

このケースが分岐するトリガーは `$item.LinkType` プロパティが非 `$null` 値（`SymbolicLink` / `Junction` / その他のリンク種別）を持つことである。

## 多層安全装置

このケースで検証される安全装置:

1. リンク種別の検出（`$item.LinkType` 真偽判定）
2. リンク追従禁止（`Get-ChildItem` の挙動と組み合わせ）
3. 親階層（`.local/`、`.claude/`）の LinkType チェック（親がリンクの場合も拒否）

## エッジケース

| 状況 | 動作 |
|-----|------|
| 親ディレクトリ（`work/`）自体がシンボリックリンク | バリデーションで拒否（親階層 LinkType チェック） |
| HardLink（Windows ではディレクトリ作成不可） | 通常パス扱い（リスクなし） |
| Junction Point | SymbolicLink と同様に拒否 |

## 関連ケース

- `case-08_validation_fail.md`（不正な名前のディレクトリ）
- `case-09_active_session.md`（進行中セッション保護）
