# Case 04: --scope local 正常系

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all --scope local` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `scope` | `local` |
| 既存状態 | カレントプロジェクトに local スコープのプラグイン 1 件 |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `scope` を `local` と確定

### Phase A: 対象収集（local スコープのみ）
- `<project>/.claude/settings.local.json` から `enabledPlugins` を Grep で抽出
- `installed_plugins.json` の `scope = local` で絞り込み
- `projectPath` がカレントプロジェクトと一致するもののみ対象

### Phase B: マーケットプレイス更新
- 必ず実行

### Phase C / D: スキップ
- User / Project スコープの Phase はスキップ

### Phase E: Local スコープのプラグイン更新
- `claude plugin update <name>@<mp> --scope local` 形式

### Phase F: 結果報告
- Local スコープのみのサマリ

### Phase G: 失敗対応
- Failed があれば AskUserQuestion

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | `claude plugin marketplace update` + `claude plugin update <name>@<mp> --scope local` ×1 |
| 標準出力（要約） | 「scope: local」「対象 1 件」 |
| 終了状態 | 全件成功なら exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `scope = local` かつ `installed_plugins.json` の `scope = local` である。

## 関連ケース

- `case-02_scope_user.md`（user スコープ）
- `case-03_scope_project.md`（project スコープ）
- `case-05_scope_all.md`（全スコープ）
