# Case 12: A-3 projectPath 不一致による Skipped（現在のプロジェクト外）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all --scope project` |
| `installed_plugins.json` | project スコープのエントリ A（`projectPath = /home/user/projA`） + エントリ B（`projectPath = /home/user/projB`） |
| 現在のリポジトリルート | `/home/user/projA` |

## 期待動作

### Phase A-0 / A-1 / A-2: 通常通り

### Phase A-3: スコープ真値判定（ADR-PU-009）
- `installed_plugins.json` を読み取り
- エントリ A: `projectPath` が現在のリポジトリと一致 → 対象に含める
- エントリ B: `projectPath` が現在のリポジトリと **不一致** → `Skipped（現在のプロジェクト外）` として記録

### Phase B / D / E: 通常実行
- B: マーケットプレイス更新
- D: エントリ A のみ更新（エントリ B は Skipped 区分のためリトライ対象外）
- E: スキップ

### Phase F: 結果報告
- サマリで Skipped の内訳を表示:
  - Skipped（現在のプロジェクト外）: 1 件（エントリ B）
- Phase F の詳細テーブルでは「対象外」と明示

### Phase G: 失敗対応
- エントリ A の更新結果に応じて発火
- Skipped はリトライ対象外（ADR-PU-007）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | MP 更新 + エントリ A のみ |
| 標準出力（要約） | "Skipped（現在のプロジェクト外）: 1 件" |
| 終了状態 | エントリ A 成功で exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `installed_plugins.json` の `projectPath` が現在のリポジトリルートと不一致 である（ADR-PU-009 で定めた Phase A-3 の最重要分岐）。

## 関連ケース

- `case-03_scope_project.md`（projectPath 一致のみで構成された正常系）
- `case-05_scope_all.md`（全スコープでも同じ A-3 ロジックが適用）
- ADR-PU-009: installed_plugins.json をスコープ判定 SSOT として採用
