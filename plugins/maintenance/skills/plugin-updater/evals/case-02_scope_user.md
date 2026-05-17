# Case 02: --scope user 正常系

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all --scope user` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `scope` | `user` |
| 既存状態 | user スコープに有効プラグイン 3 件、すべて最新版なし（更新あり） |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `scope` を `user` と確定（ホワイトリスト一致）

### Phase A: 対象収集（user スコープのみ）
- `~/.claude/settings.json` から `enabledPlugins` を Grep で抽出
- project / local スコープの抽出はスキップ
- `installed_plugins.json` の `scope` フィールドで user 以外のエントリを除外

### Phase B: マーケットプレイス更新
- `--scope` 指定でも常にマーケットプレイス更新は実行（ADR-PU-006）

### Phase C: User スコープのプラグイン更新
- 各プラグインを `claude plugin update <name>@<mp>` で順次更新
- 成功 / Failed / Skipped を区分集計

### Phase D / E: スキップ
- `--scope user` 指定のため Project / Local の Phase D / E はスキップ

### Phase F: 結果報告
- User スコープのみのサマリ + 詳細テーブル
- マーケットプレイス更新結果も併記

### Phase G: 失敗対応
- Failed がある場合のみ AskUserQuestion で「リトライ / 中止」を確認

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | `claude plugin marketplace update` + `claude plugin update <name>@<mp>` ×3 |
| 標準出力（要約） | 「===== 更新サマリ =====」「scope: user」「成功 N 件 / 失敗 N 件」 |
| 終了状態 | 全件成功なら exit 0、Phase G 経由のリトライがあれば最終状態に従う |

## 分岐の根拠

このケースが分岐するトリガーは `scope = user` である（`installed_plugins.json` の `scope` フィールドで判定）。

## 関連ケース

- `case-03_scope_project.md`（project スコープ）
- `case-04_scope_local.md`（local スコープ）
- `case-05_scope_all.md`（全スコープ）
