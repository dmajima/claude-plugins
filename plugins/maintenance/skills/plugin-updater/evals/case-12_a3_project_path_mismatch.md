# Case 12: A-3 projectPath 不一致による Skipped（target=current-project）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update`（target=current-project） |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `current-project` |
| `installed_plugins.json` | project スコープのエントリ A（`projectPath = /home/user/projA`） + エントリ B（`projectPath = /home/user/projB`） |
| 現在のリポジトリルート | `/home/user/projA` |

## 期待動作

### Phase A-0 / A-1 / A-2: 通常通り

### Phase A-3: スコープ判定（ADR-PU-009 / ADR-PU-015）
- `installed_plugins.json` を読み取り
- エントリ A: `projectPath` が現在のリポジトリと一致 → 対象に含める
- エントリ B: `projectPath` が現在のリポジトリと **不一致** → `Skipped（現在のプロジェクト外）` として記録

### Phase B / C: スキップ（target=current-project のため）

### Phase D / E: 更新実行
- D: エントリ A のみ更新（エントリ B は Skipped 区分のためリトライ対象外）
- E: 該当エントリがあれば更新

### Phase F: 結果報告
- サマリで Skipped の内訳を表示:
  - Skipped（現在のプロジェクト外）: 1 件（エントリ B）
- Phase F-4: 「全プロジェクトのプラグインを更新したい場合は `/update-all` を実行してください」

### Phase G: 失敗対応
- エントリ A の更新結果に応じて発火
- Skipped はリトライ対象外（ADR-PU-007）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | エントリ A のプラグイン更新のみ（MP 更新なし） |
| 標準出力（要約） | "Skipped（現在のプロジェクト外）: 1 件" |
| 終了状態 | エントリ A 成功で exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `target=current-project` かつ `installed_plugins.json` の `projectPath` が現在のリポジトリルートと不一致 である（ADR-PU-009 の Phase A-3 分岐 + ADR-PU-015 の target 分岐）。

## 関連ケース

- `case-02_target_current_project.md`（projectPath 一致のみで構成された正常系）
- `case-03_target_all_multi_project.md`（target=all では projectPath 不一致でも更新対象になる）
- `case-17_target_all_projectpath_missing.md`（target=all で projectPath ディレクトリ不在のケース）
- ADR-PU-009: installed_plugins.json をスコープ判定 SSOT として採用
- ADR-PU-015: 全プロジェクト更新と target パラメータの導入
