# Case 01: スキルレビュー（標準観点 3 名）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-formatter` スキルをレビュー" |
| 引数 | `code-formatter` |
| フラグ | なし |
| 既存状態 | スキルが存在 |

## 期待動作

### Phase 1: 対象判定

`SKILL.md` 含むディレクトリを検出 → スキルレビューモード。

### Phase 2: 観点選定

| エージェント | 観点 |
|------------|------|
| `implementation-engineer` | SKILL.md 構造・procedures 論理 |
| `architect` | 責務分離・SSOT 参照 |
| `test-engineer` | evals 充実度・分岐網羅 |

### Phase 3: 並列起動 + 機械チェック

3 つの Agent を 1 メッセージ内で並列起動。同時に機械チェックを実行。

### Phase 4: 結果統合

各エージェント結果と機械チェック結果を統合し、優先度別に整理。

### Phase 5: 引き渡し

Critical/High なし → `marketplace-publisher` への接続を提案
Critical/High あり → 該当 `*-toolkit` への接続を提案

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | 統合レビュー結果（Critical / High / Medium / Low / 総合判定）+ 次のアクション提案 |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = スキル（最小構成）。
