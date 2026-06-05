# Case 19: installed_plugins.json の plugins が空オブジェクト

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `all` |
| `installed_plugins.json` の内容 | `{"version": 2, "plugins": {}}` |
| 既存状態 | `enabledPlugins` に project スコープ 2 件 + local スコープ 1 件の合計 3 件が登録されているが、`installed_plugins.json` にはエントリなし / User プラグイン 2 件は `installed_plugins.json` に存在しインストール済み |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `target` を `all` と確定

### Phase A-0-2: CLI 存在チェック
- 通常通り通過

### Phase A: 対象収集
- `claude plugin marketplace list` でマーケットプレイス列挙
- User / Project / Local の全 `enabledPlugins` を A-Sec 手順で抽出

### Phase A-3: スコープ真値判定
- `installed_plugins.json` の `plugins` が `{}` のため、交差集合が空集合
- `enabledPlugins` に登録された project/local スコープ 3 件全てが `Skipped（未インストール）` として記録（`installed_plugins.json に該当エントリがありません`）
- User プラグイン 2 件はインストール済みのため通常通り対象に含める

### Phase B: マーケットプレイス更新
- マーケットプレイスを通常通り更新

### Phase C: User スコープ更新
- User プラグイン 2 件を通常通り更新

### Phase D: Project スコープ更新
- 対象なし（全 3 件が Skipped）。変更系 CLI 呼び出しなし

### Phase E: Local スコープ更新
- 対象なし（同上）。変更系 CLI 呼び出しなし

### Phase F: 結果報告
- F-1 サマリ: Project / Local の Skipped 件数を表示（「未インストール」区分）
- F-3 詳細テーブル: 各エントリの備考列に `installed_plugins.json に該当エントリがありません`（output-formats.md F-3 定型文）
- F-4 次のアクション: **Skipped（未インストール）が 1 件以上** の旨のメッセージ（「該当エントリを enabledPlugins から除外するか、claude plugin install <plugin>@<marketplace> でインストールしてください」）を出力

### Phase G: 失敗対応
- User スコープ / マーケットプレイスの Failed 件数に応じて発火（Project / Local の Skipped はリトライ対象外）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | MP 更新 + User プラグイン 2 件のみ |
| Project / Local の変更系 CLI 呼び出し | なし（全 Skipped） |
| F-3 備考列 | `installed_plugins.json に該当エントリがありません`（project/local 全 3 件） |
| F-4 アクション | 「該当エントリを enabledPlugins から除外するか、claude plugin install でインストールしてください」を含む |
| 終了状態 | User / MP が全成功なら exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `installed_plugins.json` の `plugins` が空オブジェクト `{}` であることである。`enabledPlugins` にエントリが存在しても `installed_plugins.json` との交差集合が空集合となり、project/local スコープの全エントリが `Skipped（未インストール）` となる（output-formats.md F-3「Skipped 区分定型文」の `未インストール` 分岐）。

`case-15_a3_installed_plugins_oversize.md` が `installed_plugins.json` の物理的異常（サイズ超過・version 非対応）に起因するフォールバックを扱うのに対し、本ケースは構造的に正常だが `plugins` が空というデータ上の異常を対象とする。

## 関連ケース

- `case-15_a3_installed_plugins_oversize.md`（installed_plugins.json の物理的異常 → A-3 スキップ + フォールバック）
- `case-17_target_all_projectpath_missing.md`（projectPath ディレクトリ不在による Skipped）
- output-formats.md F-3 Skipped 区分定型文（`未インストール`）
- output-formats.md F-4 次のアクション提示（Skipped（未インストール）のメッセージ）
- ADR-PU-009: installed_plugins.json をスコープ判定 SSOT として採用