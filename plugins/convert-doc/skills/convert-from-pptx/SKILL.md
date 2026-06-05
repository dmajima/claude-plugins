---
name: convert-from-pptx
description: PowerPoint (PPTX) を Markdown に変換するスキル。入力 PPTX → 出力 MD。「PPTX を Markdown に変換」「スライドを MD にして」「PowerPoint を読める形に」「設計書 PPTX を解析」「.pptx をテキスト化」等で起動。Use when converting PowerPoint to Markdown. SKIP 入力が Markdown (convert-pptx) / 出力が HTML (convert-html) / PDF (convert-pdf)。
---

# convert-from-pptx スキル

PowerPoint (PPTX) を「機械抽出 + LLM 意味解釈」の 2 フェーズで Markdown に変換するスキル。

## 設計方針

Python で全 shape の構造データを完全抽出して JSON に dump し、Claude が文脈解釈して Markdown を生成する 2 段階構成。装飾フィルタリング・タイトル推定・Mermaid 化・要素並べ替えは Claude メインコンテキストの責務。詳細は [`references/design.md`](references/design.md) を参照。

## 責務

### Phase 1: Python による構造抽出（機械的・完全保存）

- PPTX を python-pptx で読み込み、全 shape の以下を JSON に dump:
  - 識別子 (`shape_id`, `name`, `kind`)
  - 種別 (`TEXT_FRAME` / `PICTURE` / `TABLE` / `CONNECTOR` / `SMARTART` / `CHART`)
  - placeholder 情報 (`idx`, `type`)
  - グループ階層パス (`group_path`)
  - 幾何情報 (`top_emu`, `left_emu`, `width_emu`, `height_emu` および各 ratio)
  - テキストと段落 (`text`, `paragraphs[].runs[].{text, font_size_pt, bold, color}`)
  - フォント最大サイズ・主要色・グレースケール判定
  - テーブル内容 / 画像リンク / コネクタ接続情報
- スライド寸法・レイアウト名・スピーカーノート・テンプレ装飾候補テキスト（マスタ/レイアウト由来）を併記
- **装飾フィルタは適用しない**（情報損失を回避し、Claude に判断を委ねる）

### Phase 2: Claude による意味解釈（文脈ベース）

- JSON を読み込み、以下を文脈判断:
  - スライドのタイトル/見出し/本文/装飾の役割推定
  - フッタ・ページ番号・コピーライト・凡例ラベルの除外
  - フロー図・組織図・SmartArt の Mermaid 化
  - 視覚順（top → left）での要素整列
  - 関係性（コネクタ・グループ・並列レイアウト）の Markdown 構造への反映
- 最終 Markdown を出力ファイルに Write

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| Markdown → PPTX への変換 | `convert-pptx` |
| Markdown → HTML への変換 | `convert-html` |
| Markdown → PDF への変換 | `convert-pdf` |
| OCR による画像内文字認識 | 本スキルではサポートしない |
| アニメーション・スライド遷移情報の保持 | 本スキルでは破棄する |
| ピクセル単位での完全レイアウト再現 | 本スキルではベストエフォート |

## トリガー条件

- 「PPTX を Markdown に変換」「スライドを MD にして」「PowerPoint 資料を読める形にして」「設計書 PPTX を転記」等の自然言語依頼
- `/convert-from-pptx` スラッシュコマンド
- 他スキルからの `Skill(skill: "convert-from-pptx", ...)` 呼び出し

このスキルを起動しないケース:

- Markdown → PPTX への変換依頼（`convert-pptx` へルーティング）
- HTML / PDF への変換依頼（`convert-html` / `convert-pdf` へルーティング）

## 前提

- 入力 PPTX ファイルがローカルに存在し読み取り可能
- Python 3.9+ が利用可能
- 画像抽出・JSON / Markdown 出力先ディレクトリへの書き込み権限があること

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 引数で入力 PPTX / 出力 MD / 全オプションが指定 / `--non-interactive` 相当 | 非対話 | 確認を求めずデフォルト値で進行 |
| `--no-mermaid` / `--include-notes` / `--include-hidden` 等の指定 | カスタム | 指定オプションに従って処理 |
| 上記以外（自然言語依頼） | 対話 | 不足パラメータを `AskUserQuestion` でユーザに確認 |

## サイズ別フロー選択

| 規模 | 目安 | 推奨フロー | 詳細 |
|------|------|-----------|------|
| 小規模 | スライド数 30 以下 / JSON 1 MB 以下 | 単一 JSON 全読み込み（下記 2 フェーズ） | このページの「実行フロー（2 フェーズ）」 |
| 中規模 | スライド数 30〜100 | per-slide JSON + compact view（メインで逐次 Read） | [`references/large-pptx-workflow.md`](references/large-pptx-workflow.md) 節 2 |
| 大規模 | スライド数 100 超 | per-slide JSON + サブエージェント並列分担 | [`references/large-pptx-workflow.md`](references/large-pptx-workflow.md) 節 3 |

判断は **shape 数の総和** が支配的（密度の高いスライドが多いと中規模でも分割推奨）。`metadata.json` の `slides_index` で確認。

## 実行フロー（2 フェーズ・推奨）

1. **ワークディレクトリ作成**（`.claude/.local/work/yyyyMMdd_nn_convert_from_pptx/{inputs,workspace}`）
2. **venv 構築**（`workspace/.venv` 配下、`${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh`）
3. **Phase 1: 構造化 JSON 抽出**
   ```bash
   "$SESSION_DIR/workspace/.venv/Scripts/python.exe" \
     "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py" \
     "<入力 PPTX パス>" \
     --structured-json "<セッション>/structured.json" \
     --json-only \
     [--include-notes] [--include-hidden]
   ``\
4. **Phase 2: Claude による意味解釈**
   - Claude メインコンテキストが `structured.json` を Read で読み込み
   - スライドごとに以下を判断:
     - タイトル shape の特定（最上部・横長・短文、または最大フォントサイズ）
     - 装飾要素の除外（FOOTER/SLIDE_NUMBER placeholder、`template_decoration_texts`、薄いグレー色、極小フォント、繰り返し短文）
     - フロー図/組織図の Mermaid 化（`connectors` 配列を解析し、`begin_shape_id`/`end_shape_id` で接続関係を再構成）
     - テーブルの GFM 変換（`table.rows`）
     - 画像の参照リンク追加（`image.markdown_link`）
     - 視覚順での要素並べ替え（`geometry.top_ratio` / `left_ratio`）
   - 構造化された Markdown を出力ファイルに Write
5. **画像ファイル**は Phase 1 で `<basename>_images/` に既に抽出済み（Markdown から相対参照可能）
6. **Phase 3: カバレッジ検証**
   ```bash
   "$SESSION_DIR/workspace/.venv/Scripts/python.exe" \
     "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/verify_md.py" \
     "<入力 PPTX パス>" \
     "<生成 MD パス>" \
     --report "<セッション>/coverage_report.json" \
     --threshold 0.85
   ``\
   - Python が機械的にテキスト/テーブル/画像/コネクタのカバレッジを集計
   - PASSED の場合は完了、FAILED の場合は Claude が `missing_texts` / `suspicious_md_phrases` を文脈分類し MD を修正 → 再検証ループ
   - 詳細: [`references/validation.md`](references/validation.md)
7. **venv 削除**（必要に応じて）

詳細な実行手順は [`references/procedures.md`](references/procedures.md)、環境構築は [`references/setup.md`](references/setup.md) を参照。

## 実行フロー（フォールバック・Python 単独）

LLM 呼び出しが行えない自動処理コンテキストでは、従来通り Python 単独で Markdown を直接生成する:

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python.exe" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py" \
  "<入力 PPTX>" "<出力 MD>" [--include-notes]
```

この場合、装飾フィルタ・タイトル推定・Mermaid 化は Python 内のヒューリスティック（フォントサイズ統計・位置統計・色判定）で実行される。品質は対話モード（2 フェーズ）に劣るが、人手介入なしで完結する。

## スライド → Markdown の対応規則

Phase 2 で Claude が JSON を解釈する際の規則は [`references/design.md`](references/design.md) を参照。

## アセットの場所

- 変換スクリプト: `${env:CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py`
- 検証スクリプト: `${env:CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/verify_md.py`
- venv セットアップ: `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh`
- venv 撤去: `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh`
- 大規模 PPTX 等で Python ハング事象の懸念がある場合は、`run_via_job.sh`ラッパー経由で起動できる。Bash ツール経由なら Start-Job 二段構成は不要

## オプション

CLI オプションの一覧と選択ガイドは [`references/options.md`](references/options.md) を参照。

## 重要な制約

- 画像出力先は出力先のディレクトリ配下に強制（パストラバーサル対策）
- 入力 PPTX は ZIP コンテナとしての妥当性を簡易検証（マジックバイト `PK\x03\x04`）してから python-pptx に渡す
- SmartArt は python-pptx が完全サポートしないため、`diagramData` 名前空間の XML を直接読み解く
- フロー図の Mermaid 化は `connectors` 配列（`stCxn` / `endCxn`）を対象とする。手書きの矢印などコネクタ要素として登録されていない接続は検出できない
- アニメーション・スライド遷移情報・スライドマスター上の純装飾は破棄する
- Phase 2 で Claude が JSON を解釈する際、`template_decoration_texts` リストにあるテキストは装飾候補だが、本文として意図的に使われている可能性も考慮（誤除外を避けるため、本文ワードと完全一致するもののみ除外）

## 参照

| 用途 | ファイル |
|-----|---------|
| 設計方針・対応規則 | [`references/design.md`](references/design.md) |
| 環境構築 | [`references/setup.md`](references/setup.md) |
| 変換実行手順 | [`references/procedures.md`](references/procedures.md) |
| CLI オプション一覧 | [`references/options.md`](references/options.md) |
| JSON スキーマと Phase 2 解釈ガイド | [`references/json-schema.md`](references/json-schema.md) |
| Phase 3 検証ガイド（漏れ・誤転記の担保） | [`references/validation.md`](references/validation.md) |
| 大規模 PPTX のサイズ別フロー | [`references/large-pptx-workflow.md`](references/large-pptx-workflow.md) |
| 動作分岐の期待挙動ケース | [`evals/`](evals/) |
