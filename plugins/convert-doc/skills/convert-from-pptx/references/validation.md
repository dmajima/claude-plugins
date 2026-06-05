# Phase 3: 検証ガイド（情報の漏れ・誤転記の担保）

PPTX → Markdown 変換の最終フェーズとして、生成された Markdown が元 PPTX の内容を漏れなく / 誤りなく反映していることを担保するための **機械検証 + Claude 文脈検証** の 2 段階フロー。

> このフェーズは大規模 PPTX を分割処理した後だけでなく、小規模 PPTX の単発変換でも実施することを推奨する。

## 1. 検証の目的

| 観点 | 検出対象 | 重大度 |
|---|---|---|
| 漏れ | PPTX 内のテキスト / テーブルセル / 画像 / コネクタが MD に転記されていない | 高 |
| 誤転記（捏造） | MD 内のテキストが PPTX のどこにも存在しない（Claude が補足解釈で追加した文言） | 高 |
| カバレッジ低下 | 装飾を除外した本文のカバレッジが閾値未満 | 中 |
| 構造ずれ | フロー図のノード/エッジ数が PPTX のコネクタ数と乖離 | 低 |

## 2. 機械検証（Python: verify_md.py）

### 2.1 実行

```bash
& "$SESSION_DIR/workspace/.venv/Scripts/python.exe" \
  "$CLAUDE_PLUGIN_ROOT/references/scripts/convert-from-pptx/verify_md.py" \
  "<入力 PPTX>" \
  "<生成 MD>" \
  --report "<セッション>/coverage_report.json" \
  --threshold 0.85
```
### 2.2 出力 (`coverage_report.json`)

| フィールド | 内容 |
|---|---|
| `summary.text_coverage` | 装飾除外後のテキスト カバレッジ率 |
| `summary.table_cell_coverage` | 装飾除外後のテーブル セル カバレッジ率 |
| `summary.pptx_image_total` / `summary.md_image_total` | PPTX 画像 shape 数 / MD 内 `![](...)` 数 |
| `summary.pptx_connector_total` / `summary.mermaid_edge_total` | PPTX コネクタ数 / MD 内 Mermaid edge 数 |
| `summary.text_template_excluded` | テンプレ装飾として除外したテキスト shape 数 |
| `summary.text_offscreen_excluded` | 画面外 (top<0 など) として除外したテキスト shape 数 |
| `summary.suspicious_md_phrase_count` | PPTX に存在しない MD フレーズの件数（誤転記候補） |
| `missing_texts` | カバレッジ計算で漏れた PPTX テキスト一覧（最大表示は `--max-missing-shown`） |
| `missing_table_cells` | 漏れたテーブル セル一覧 |
| `suspicious_md_phrases` | PPTX に存在しない MD フレーズ一覧 |
| `failures` | 閾値未達などの失敗理由一覧 |
| `passed` | 検証 PASS / FAIL の真偽値 |

### 2.3 機械検証の判定

| 閾値 | 推奨値 | 解釈 |
|---|---|---|
| `text_coverage` | 0.85 以上 | 装飾を除外した本文の 85% 以上が MD に転記されている |
| `table_cell_coverage` | 0.85 以上 | テーブル セルの 85% 以上が MD に存在 |
| `images` | PPTX 画像数の 50% 以上 | 抽出可能な画像（埋め込みあり）を取りこぼしていない |
| `connectors` | PPTX コネクタ 5 件以上ある場合は Mermaid edge が 0 でないこと | フロー図が破棄されていない |

`failures` が空の場合は機械検証 PASSED。空でない場合は次の Phase 3.2 で人手 / Claude 判定を行う。

### 2.4 機械検証の限界

検証ツールは構造化された文字列比較であり、以下は機械的には判定できない:

- 同義語 / 言い換え（「サポート」⇔「支援」）の妥当性
- 章番号や記号の保持の妥当性（`01` を `1.` に変換した場合の意味的同値性）
- フロー図 Mermaid のノード接続関係の意味的妥当性
- 「補足説明」が PPTX に存在しないだけで、解釈として妥当な場合

これらの偽陽性 / 偽陰性は Phase 3.2 の Claude 検証で吸収する。

## 3. Claude 文脈検証（手動・対話）

機械検証で FAIL となったか、`suspicious_md_phrases` / `missing_texts` の一覧に該当が出た場合、以下を Claude（メインコンテキスト）が判定する。

### 3.1 missing_texts の分類

各エントリについて以下を判定する:

| 判定 | 内容 | 対応 |
|---|---|---|
| 装飾の意図的除外 | テンプレ装飾 / 凡例ラベル / 画面外要素 / 重複ラベル | 無視 |
| 構造変換による分散 | 元 PPTX で 1 段落だったテキストを箇条書きやテーブル化で分解した | 各断片が MD 内に存在することを Claude が確認 → 無視 |
| **真の漏れ** | 重要情報（連絡先 / 数値 / 日付 / URL 等）が完全に欠落 | **MD を修正して追記** |

### 3.2 suspicious_md_phrases の分類

各エントリについて以下を判定する:

| 判定 | 内容 | 対応 |
|---|---|---|
| 機械検証の偽陽性 | Mermaid 構文（ノード ID）、Markdown 構文（テーブル罫線・リンク）、PPTX に存在する語の言い換え | 無視 |
| 補足説明としての追加 | Claude が解釈時に「わかりやすさ」のために追加した補足文 | **削除する**（PPTX 忠実度を優先）または `<!-- 補足: ... -->` で明示マーク |
| **誤転記** | PPTX に存在しない事実・人名・数値・URL を MD が含む | **必ず削除**（捏造防止） |

### 3.3 判定の検証ループ

1. 機械検証 (`verify_md.py`) で `coverage_report.json` を生成
2. Claude が `missing_texts` / `missing_table_cells` / `suspicious_md_phrases` を上記の表で分類
3. 「真の漏れ」「補足説明」「誤転記」に該当するものを MD に修正反映
4. 機械検証を再実行 → PASSED まで繰り返す
5. PASSED 後も `suspicious_md_phrases` を最終目視確認（誤転記の取り残し防止）

## 4. 大規模 PPTX での適用

スライド分割（`--per-slide-json` / `--compact-view`）で部分 MD を生成した後、**全部分 MD を統合した最終 MD を作成してから検証を実行する**。分割単位での検証は誤判定を生むため避ける（あるスライドに分散したテキストを別スライドで処理した場合、分割検証では漏れと誤判定される）。

詳細手順は [`large-pptx-workflow.md`](large-pptx-workflow.md) を参照。

## 5. CI / 自動化

`verify_md.py` は exit code を返す（PASS=0 / FAIL=1）ため、CI に組み込み可能:

```yaml
- name: Verify PPTX→MD coverage
  run: |
    python verify_md.py input.pptx output.md --report report.json --threshold 0.85
```

ただし `suspicious_md_phrases` は警告ベースであり、自動的に FAIL にはしない設計。誤転記検出は人手による最終確認を前提とする。

## 6. 検証出力の保存場所

セッション フォルダ直下に保存（グローバルルール `~/.claude/rules/claude/work-directory.md` の規約に準拠）:

```
.claude/.local/work/{session}/
├── <出力MD>.md
├── coverage_report.json     ← Phase 3 機械検証レポート
├── inputs/
└── workspace/
```

検証レポートは成果物の一部としてセッション フォルダ直下に保持し、引き渡し時に同梱する。
