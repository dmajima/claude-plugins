# Case 14: マーケットプレイス本体レビュー（個別 3 名並列）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`dmajima-claude-plugins` マーケットプレイスをレビュー" |
| 引数 | `dmajima-claude-plugins`（リポジトリルート） |
| フラグ | なし |
| 既存状態 | `.claude-plugin/marketplace.json` + マーケットプレイス README 既存 |

## 期待動作

### Phase 1: 対象判定

`.claude-plugin/marketplace.json` 含むリポジトリルートを検出。
**プラグイン（`.claude-plugin/plugin.json`）と区別** し、マーケットプレイスレビューモードに切替。

### Phase 2: チーム選定

[`../references/team-selection.md`](../references/team-selection.md) に従い、専用チームなし、個別 3 名並列:

| メンバー | 配布元 | 役割 |
|--------|-------|------|
| `marketplace-fit-reviewer` | プラグイン同梱 | リード（マーケットプレイス整合・命名衝突） |
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠（README + marketplace.json 構造） |
| `architect` | グローバル | 構造妥当性 + 拡張性 |

### Phase 3: 並列起動 + 機械チェック

3 名を 1 メッセージ内で並列 Agent 起動。並行して機械チェック:

| チェック | 対象 |
|---------|-----|
| `marketplace.json` JSON valid | 必須 |
| `name` がリポジトリディレクトリ名と一致 | 必須 |
| 各 `plugins[].source` が実在 | 必須 |
| 各 `plugins[].name` が `<source>/.claude-plugin/plugin.json` の `name` と一致 | 必須 |
| マーケットプレイス README にプラグイン一覧テーブル存在 | 必須 |
| テーブル行数 = `plugins[]` 件数 | 必須 |
| バージョン列 = 各 `plugin.json` の `version` | 必須 |
| マーケットプレイス追加方法（A: URL / B: ローカル複製）両記載 | 必須 |
| 自動更新セクション存在 | 必須 |

詳細は [`../references/automated-checks.md`](../references/automated-checks.md) を参照。

### Phase 4: 結果統合

3 名の結果と機械チェック結果を統合し、優先度別に整理。

### Phase 5: 引き渡し

| 結果 | 接続先 |
|-----|-------|
| Critical/High なし | OK 表示 |
| Critical/High あり | `marketplace-toolkit` への接続を提案（README 同期や `marketplace.json` 編集が必要） |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | 3 名の結果 + 機械チェック結果 + 統合判定 |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = マーケットプレイス → 専用チームなし、`marketplace-fit-reviewer` をリードとして 3 名並列。

## 関連ケース

- `case-02_plugin_review.md`（プラグイン全体レビュー、フック含有 6 名構成）
- `case-13_plugin_review_no_hook.md`（プラグイン全体レビュー、フック非含有 5 名構成）
