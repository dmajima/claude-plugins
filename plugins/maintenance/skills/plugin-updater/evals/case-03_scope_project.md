# Case 03: --scope project 正常系

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all --scope project` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `scope` | `project` |
| 既存状態 | カレントプロジェクトに project スコープのプラグイン 2 件、別プロジェクトに 1 件 |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `scope` を `project` と確定

### Phase A: 対象収集（project スコープのみ）
- `<project>/.claude/settings.json` から `enabledPlugins` を Grep で抽出
- `installed_plugins.json` の `projectPath` フィールドでカレントプロジェクト一致を確認
- 別プロジェクトの project スコープエントリは除外（ADR-PU-009）

### Phase B: マーケットプレイス更新
- 必ず実行

### Phase C: スキップ
- `--scope project` のため User スコープの Phase C はスキップ

### Phase D: Project スコープのプラグイン更新
- カレントプロジェクトの project エントリのみ更新
- `installed_plugins.json` で `projectPath` がカレントと一致するもののみ対象

### Phase E: スキップ
- Local スコープの Phase E はスキップ

### Phase F: 結果報告
- Project スコープのみのサマリ
- `installed_plugins.json` で除外された別プロジェクト分の件数も「除外」として明示

### Phase G: 失敗対応
- Failed があれば AskUserQuestion

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | `claude plugin marketplace update` + `claude plugin update <name>@<mp> --scope project` ×2 |
| 標準出力（要約） | 「scope: project」「除外: 別プロジェクト 1 件」 |
| 終了状態 | 全件成功なら exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `scope = project` かつ `installed_plugins.json` の `projectPath` がカレントと一致 である。

## 関連ケース

- `case-02_scope_user.md`（user スコープ）
- `case-04_scope_local.md`（local スコープ）
- ADR-PU-009: `installed_plugins.json` のスコープ判定 SSOT
