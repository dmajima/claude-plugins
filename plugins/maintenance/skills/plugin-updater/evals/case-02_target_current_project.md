# Case 02: target=current-project 正常系（/update コマンド経由）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update` コマンド経由（target=current-project を委譲） |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `current-project` |
| 既存状態 | git リポジトリ内（`<repo>`）。Project スコープに 2 件、Local スコープに 1 件のプラグインが有効化済み |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `target` を `current-project` と確定（ホワイトリスト一致）

### Phase A-0-2: Claude Code CLI 存在チェック
- 必要サブコマンドの存在を確認

### Phase A: 対象収集（current-project）
- `<repo>/.claude/settings.json` から Project スコープの `enabledPlugins` を Grep で抽出（XR-Sec）
- `<repo>/.claude/settings.local.json` から Local スコープの `enabledPlugins` を Grep で抽出（XR-Sec）
- `~/.claude/settings.json`（User スコープ）の抽出はスキップ
- マーケットプレイス一覧の取得（`claude plugin marketplace list`）はスキップ

### Phase A-1〜A-3: 入力検証
- プラグイン名 / スコープ名の正規表現照合（XR-1）
- `installed_plugins.json` の `scope` / `projectPath` で現在の `<repo>` に一致するエントリのみを対象とする

### Phase B: マーケットプレイス更新 — スキップ
- `target=current-project` の場合、Phase B はスキップ（ADR-PU-015 / ADR-PU-003）
- `claude plugin marketplace update` は呼び出さない

### Phase C: User スコープのプラグイン更新 — スキップ
- `target=current-project` の場合、Phase C はスキップ（ADR-PU-015）
- User プラグインは更新対象外

### Phase D: Project スコープのプラグイン更新
- 現在の `<repo>` の Project スコープに一致するエントリ 2 件を `claude plugin update <name>@<mp> --scope project` で順次更新
- 成功 / Failed / Skipped を区分集計

### Phase E: Local スコープのプラグイン更新
- 現在の `<repo>` の Local スコープに一致するエントリ 1 件を `claude plugin update <name>@<mp> --scope local` で更新

### Phase F: 結果報告
- `target=current-project` のため projectPath ヘッダなしの通常テーブル（`output-formats.md` F-3 参照）
- Phase B（マーケットプレイス）/ Phase C（User）がスキップされた旨を明示
- Project / Local スコープのみのサマリ + 詳細テーブル

### Phase G: 失敗対応
- Failed がある場合のみ AskUserQuestion で「リトライ / 中止」を確認

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | `claude plugin update <name>@<mp> --scope project` ×2 + `claude plugin update <name>@<mp> --scope local` ×1 |
| Phase B（MP 更新） | スキップ |
| Phase C（User 更新） | スキップ |
| 標準出力（要約） | 「===== 更新サマリ =====」「target: current-project」「成功 N 件 / 失敗 N 件」 |
| Phase F テーブル形式 | projectPath ヘッダなしの通常テーブル |
| 終了状態 | 全件成功なら exit 0、Phase G 経由のリトライがあれば最終状態に従う |

## 分岐の根拠

このケースが分岐するトリガーは `target = current-project` かつ git リポジトリ内での起動 である（ADR-PU-015）。
`installed_plugins.json` の `projectPath` が `<repo>` と一致するエントリのみが対象となる。

## 関連ケース

- `case-03_target_all_multi_project.md`（target=all で複数 projectPath のケース）
- `case-04_target_current_project_no_repo.md`（target=current-project + git リポジトリ外のエラーケース）
- `case-05_target_all.md`（target=all 正常系）
- ADR-PU-015: `target` パラメータの導入（`current-project` の定義）