# Case 21: target=all + git リポジトリ外（INFO 表示 + projectPath ベース更新）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `all` |
| 既存状態 | git リポジトリ外のディレクトリで実行。`installed_plugins.json` に projA（実在）の project エントリあり。User 1 件、マーケットプレイス 2 件 |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `target` を `all` と確定

### Phase A-Repo: git リポジトリ存在確認
- `target=all` かつリポジトリ外 → エラーにはならない（`target=current-project` のみエラー）
- 以下の INFO を表示（`output-formats.md` SSOT 参照）:
  ```
  INFO: git リポジトリ外で実行されたため、target=all でも現在のプロジェクトの Project / Local スコープはありません。
  他プロジェクトの Project / Local プラグインは installed_plugins.json の projectPath に基づいて更新されます。
  ```

### Phase A: 対象収集
- `~/.claude/settings.json`（user）から `enabledPlugins` 抽出
- `claude plugin marketplace list` 実行
- リポジトリ外のため `<repo>/.claude/settings.json` / `settings.local.json` は不在

### Phase A-3: スコープ判定
- `installed_plugins.json` の全エントリを走査
- projA の project エントリ: ディレクトリ実在 → 対象

### Phase B: マーケットプレイス更新
- `claude plugin marketplace update` を実行

### Phase C: User スコープ更新
- User 1 件を更新

### Phase D: Project スコープ更新
- `(cd projA && claude plugin update <name>@<mp> --scope project)` を実行

### Phase F: 結果報告
- INFO メッセージを含めた結果表示
- Project プラグインは projectPath ヘッダ付きグルーピング

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| INFO 表示 | `output-formats.md`「git リポジトリ外で target=all の場合の INFO」参照 |
| 変更系 CLI 呼び出し | MP 更新 + User 1 + Project 1（projA） |
| 終了状態 | 全件成功なら exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `target=all` かつ git リポジトリ外 である（ADR-PU-015 / phase-flow.md A-Repo「target と git リポジトリの関係」テーブル）。

`target=current-project` + リポジトリ外はエラー中断（case-04）だが、`target=all` はリポジトリ外でも `installed_plugins.json` ベースで他プロジェクトのプラグインを更新可能。

## 関連ケース

- `case-04_target_current_project_no_repo.md`（target=current-project + リポジトリ外 → エラー）
- `case-05_target_all.md`（target=all + リポジトリ内の正常系）
- ADR-PU-015: `target` パラメータの導入
