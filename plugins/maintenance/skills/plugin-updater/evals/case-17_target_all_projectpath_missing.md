# Case 17: target=all で全 projectPath のディレクトリが不在

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `all` |
| 既存状態 | User プラグイン 2 件あり / `installed_plugins.json` に projA（`projectPath = /home/user/projA`）と projB（`projectPath = /home/user/projB`）の project/local エントリが計 3 件 / ただし `/home/user/projA` も `/home/user/projB` もディレクトリとして存在しない |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `target` を `all` と確定

### Phase A-0-2: CLI 存在チェック
- 通常通り通過

### Phase A: 対象収集
- `claude plugin marketplace list` でマーケットプレイス列挙
- User / Project / Local の全 `enabledPlugins` を A-Sec 手順で抽出

### Phase A-1 / A-2 / A-3: 入力検証
- A-3: `installed_plugins.json` の全 project/local エントリに対して projectPath のディレクトリ実在確認
  - projA の全エントリ（`/home/user/projA`）: ディレクトリ不在 → `Skipped（projectPath ディレクトリ不在）` として記録
  - projB の全エントリ（`/home/user/projB`）: ディレクトリ不在 → 同上

### Phase B: マーケットプレイス更新
- マーケットプレイスを通常通り更新（User スコープとは独立）

### Phase C: User スコープ更新
- User プラグイン 2 件を通常通り更新

### Phase D / E: Project / Local スコープ更新
- 全エントリが `Skipped（projectPath ディレクトリ不在）` のため変更系 CLI 呼び出しなし

### Phase F: 結果報告
- F-1 サマリ: Project / Local の Skipped 件数を表示
- F-3 詳細テーブル: 全 project/local エントリの備考列に `projectPath のディレクトリが存在しないためスキップしました` を表示（output-formats.md F-3 定型文）
- F-4 次のアクション: **Skipped（projectPath ディレクトリ不在）が 1 件以上** の旨のメッセージ（「該当 projectPath のディレクトリが存在しません。ディレクトリを復元するか、enabledPlugins から除外してください」）を出力

### Phase G: 失敗対応
- User スコープ / マーケットプレイスの Failed 件数に応じて発火（Project / Local の Skipped はリトライ対象外）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | MP 更新 + User プラグイン 2 件のみ |
| Project / Local の変更系 CLI 呼び出し | なし（全 Skipped） |
| F-3 備考列 | `projectPath のディレクトリが存在しないためスキップしました`（projA / projB 全エントリ） |
| F-4 アクション | 「該当 projectPath のディレクトリが存在しません。ディレクトリを復元するか、enabledPlugins から除外してください」を含む |
| 終了状態 | User / MP が全成功なら exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `target=all` 時に `installed_plugins.json` の projectPath ディレクトリが実在しないことである（output-formats.md F-3「Skipped 区分定型文」の `projectPath ディレクトリ不在` 分岐）。

`case-12_a3_project_path_mismatch.md` が `target=current-project` 相当（projectPath 不一致）の Skipped を扱うのに対し、本ケースは `target=all` 環境でのディレクトリ実在確認失敗を対象とする。

## 関連ケース

- `case-12_a3_project_path_mismatch.md`（projectPath 不一致 → Skipped（現在のプロジェクト外））
- `case-19_installed_plugins_empty.md`（installed_plugins.json の plugins が空で全エントリ Skipped）
- output-formats.md F-3 Skipped 区分定型文（`projectPath ディレクトリ不在`）
- output-formats.md F-4 次のアクション提示（Skipped（projectPath ディレクトリ不在）のメッセージ）