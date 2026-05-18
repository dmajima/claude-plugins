# Case 15: A-3 で installed_plugins.json が 4000 行超 → フォールバック

## 入力（複合）

### Sub-case 15-A: 行数 4000 行超

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| `installed_plugins.json` | 4500 行・3 MB |
| 他状態 | A-Sec までは正常通過 |

### Sub-case 15-B: スキーマバージョン非対応（version=99）

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| `installed_plugins.json` | `{ "version": 99, "plugins": [...] }` |
| 他状態 | A-Sec までは正常通過 |

## 期待動作

### Phase A-0 / A-1 / A-2 / A-Sec: 通常通り

### Phase A-3: スコープ真値判定
- Sub-case A: 4000 行 / 1 MB の上限を超過 → A-3 を **スキップしてフォールバック継続**
- Sub-case B: `version` が 2 以外 → A-3 を **スキップしてフォールバック継続 + INFO 出力**
- いずれの場合も、A で抽出した `enabledPlugins` リスト（Phase A-Sec 経由）を Update 対象として継続
- `projectPath` による厳密判定は行われず、project / local スコープでは「すべての enabledPlugins
  を試行し、CLI 側で対象外の場合はスキップさせる」フォールバック挙動

### Phase F: 結果報告
- INFO メッセージで「A-3 はスキップされました（installed_plugins.json サイズ超過 / version 非対応）」を明示
- 通常通り Phase B〜E の結果を集計

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| A-Sec | 通常通り |
| A-3 | スキップ + INFO 出力 |
| Phase B〜E | 通常実行（フォールバック対象を試行） |
| 終了状態 | exit 0（フォールバック成功時） |

## 分岐の根拠

各 sub-case が分岐するトリガー:

- A: `installed_plugins.json` のサイズ 4000 行超 / 1 MB 超
- B: `installed_plugins.json` の `version` フィールドが 2 以外

## 設計意図

`installed_plugins.json` の異常状態（DoS 抑制 / スキーマ変更）でも、A-Sec で取得した
`enabledPlugins` リストを使った最低限の更新は実行できるようにする「フェイルソフト」設計。
完全失敗 (exit 1) ではなく INFO 警告 + フォールバックで継続する。

## 関連ケース

- `case-12_a3_project_path_mismatch.md`（A-3 正常系での projectPath 判定）
- ADR-PU-009: installed_plugins.json をスコープ判定 SSOT として採用
- phase-flow.md A-3-1 / A-3-2 詳細仕様
