# Case 03: target=all で複数 projectPath を持つケース

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `all` |
| 既存状態 | `installed_plugins.json` に projA（Project 2 件・Local 1 件）と projB（Project 1 件）の 2 プロジェクトのエントリが存在する。User スコープにプラグイン 2 件。マーケットプレイス 2 件 |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `target` を `all` と確定

### Phase A-0-2: Claude Code CLI 存在チェック
- 必要サブコマンドの存在を確認

### Phase A: 対象収集（全スコープ）
- `~/.claude/settings.json`（User）から `enabledPlugins` を Grep で抽出（XR-Sec）
- `installed_plugins.json` の `projectPath` 一覧（projA / projB）を取得し、各プロジェクトの `settings.json` / `settings.local.json` から `enabledPlugins` を抽出

### Phase A-1〜A-3: 入力検証
- プラグイン名 / MP 名 / スコープ名の正規表現照合（XR-1）
- `installed_plugins.json` の `scope` / `projectPath` で projA・projB の全エントリを対象に収集（target=all のため全 projectPath が対象）
- ディレクトリが実在する projA / projB を更新対象として確定

### Phase B: マーケットプレイス更新
- `claude plugin marketplace update`（引数なし・全 MP 一括）を 1 回実行

### Phase C: User スコープのプラグイン更新
- User スコープのプラグイン 2 件を `claude plugin update <name>@<mp>` で順次更新

### Phase D: Project スコープのプラグイン更新（全 projectPath）
- **projA** の Project スコープ 2 件を更新（`cd projA` 後に `claude plugin update <name>@<mp> --scope project`）
- **projB** の Project スコープ 1 件を更新（`cd projB` 後に `claude plugin update <name>@<mp> --scope project`）

### Phase E: Local スコープのプラグイン更新（全 projectPath）
- **projA** の Local スコープ 1 件を更新（`cd projA` 後に `claude plugin update <name>@<mp> --scope local`）
- projB に Local スコープのエントリなし → スキップ

### Phase F: 結果報告
- `target=all` のため Project / Local プラグインは **projectPath ごとにグルーピング**して表示（`output-formats.md` F-3 参照）
- projA セクション・projB セクションに分けてテーブルを出力
- マーケットプレイス更新結果も併記
- 全体サマリ（成功 / 失敗 / Skipped / Missing の区分集計）

### Phase G: 失敗対応
- Failed が出た場合のみ AskUserQuestion

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | MP 更新 ×2 + User 更新 ×2 + projA Project ×2 + projB Project ×1 + projA Local ×1 |
| 標準出力（要約） | 「===== 更新サマリ =====」「target: all」 |
| Phase F テーブル形式 | projectPath ヘッダ（`#### <projA（XR-3 サニタイズ済み）>`）付きのグルーピングテーブル |
| 終了状態 | 全件成功なら exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `target = all` かつ `installed_plugins.json` に複数の `projectPath` が存在する ことである（ADR-PU-015 / ADR-PU-009）。
`installed_plugins.json` の全 `projectPath` を走査し、ディレクトリが実在するものをすべて更新対象とする。

## 関連ケース

- `case-02_target_current_project.md`（target=current-project 正常系）
- `case-05_target_all.md`（target=all 単一プロジェクトの正常系）
- `case-12_a3_project_path_mismatch.md`（projectPath ディレクトリ不在の場合の Skipped）
- ADR-PU-015: `target` パラメータの導入（全プロジェクト更新の定義）
- ADR-PU-009: `installed_plugins.json` をスコープ判定の SSOT に採用