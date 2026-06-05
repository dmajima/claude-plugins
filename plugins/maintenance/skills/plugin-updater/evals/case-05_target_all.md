# Case 05: target=all（既定）正常系

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all`（引数なし）または `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `all` |
| 既存状態 | user 2 件 / project 1 件（1 プロジェクト）/ local 1 件のプラグイン、マーケットプレイス 3 件 |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `target` を `all` と確定（引数なしの既定値、ADR-PU-014 フェイルセーフ）

### Phase A: 対象収集（全スコープ）
- `~/.claude/settings.json`（user）
- 全 `projectPath` の `<project>/.claude/settings.json`（project）
- 全 `projectPath` の `<project>/.claude/settings.local.json`（local）
- すべてから `enabledPlugins` のみ Grep で抽出（XR-Sec）

### Phase B: マーケットプレイス更新
- `claude plugin marketplace update`（引数なし・全 MP 一括）を 1 回実行

### Phase C → D → E: 各スコープのプラグイン更新
- C: User 2 件
- D: Project 1 件（`installed_plugins.json` の `projectPath` に一致するもの）
- E: Local 1 件（同上）

### Phase F: 結果報告
- スコープ別の詳細テーブル（`output-formats.md` F-3 参照）
- `target=all` のため、Project / Local プラグインは **projectPath ごとにグルーピング**して表示する
- マーケットプレイス更新サマリ
- 全体サマリ（成功 / 失敗 / Skipped / Missing の区分集計）

### Phase G: 失敗対応
- Failed が出た場合のみ AskUserQuestion

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | MP 更新 ×3 + Plugin 更新 ×4 |
| 標準出力（要約） | 「target: all」「user: 2 / project: 1 / local: 1」 |
| Phase F テーブル形式 | projectPath ヘッダ付きのグルーピングテーブル（Project / Local プラグイン） |
| 終了状態 | 全件成功なら exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `target = all`（既定）である（ADR-PU-015）。

## 関連ケース

- `case-01_dry_run.md`（同じ target=all だが mode = dry-run）
- `case-02_target_current_project.md`（target=current-project 正常系）
- `case-03_target_all_multi_project.md`（target=all で複数 projectPath のケース）
- `case-08_circuit_breaker.md`（Phase B 失敗時のサーキットブレーカー連動）
- ADR-PU-015: `target` パラメータの導入