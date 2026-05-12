---
name: convert-from-pptx
description: PowerPoint (PPTX) ファイルを Markdown に変換・転記するスキル（入力 PPTX → 出力 MD）。各スライドを ## 見出しに、テキスト・箇条書き・表・画像を Markdown へ、図形＋コネクタや SmartArt のフロー図は Mermaid flowchart 化、スピーカーノートも任意出力。「PPTX を Markdown に変換」「スライドを MD にして」「PowerPoint を読める形に」「設計書 PPTX を解析して」等で起動する。Use when reading, transcribing or analyzing PPTX content into Markdown. SKIP when input is Markdown (use convert-pptx for MD→PPTX) or when output is HTML (convert-html) / PDF (convert-pdf).
---

# convert-from-pptx スキル

PowerPoint (PPTX) ファイルを Claude が読み込める Markdown に変換（転記）するスキル。

## 責務

- PPTX → Markdown への構造化転記
- 各スライドを `## スライドタイトル` セクションとして出力（1枚目はタイトルスライドとして `# タイトル`）
- テキスト・箇条書き（レベル保持）・表・画像・コードブロック（モノスペースフォント検出）・スピーカーノートの転記
- 図形 + コネクタ構成のフロー図および SmartArt 階層図を Mermaid `flowchart` に変換
- 画像は別ファイルとして抽出し、Markdown では相対パスで参照（Claude が再読込可能な形）

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
- 画像抽出のため出力先ディレクトリへの書き込み権限があること

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 引数で入力 PPTX / 出力 MD / 全オプションが指定 / `--non-interactive` 相当 | 非対話 | 確認を求めずデフォルト値で進行 |
| `--no-mermaid` / `--include-notes` / `--include-hidden` 等の指定 | カスタム | 指定オプションに従って処理 |
| 上記以外（自然言語依頼） | 対話 | 不足パラメータを `AskUserQuestion` でユーザに確認 |

## 実行フロー

1. **ワークディレクトリ作成**（`.claude/.local/work/yyyyMMdd_nn_convert_from_pptx/{inputs,workspace}`）
2. **venv 構築**（`workspace/.venv` 配下、`${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh` を利用）→ 統合 requirements をインストール
3. **変換スクリプト実行**（`${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py`）
4. **画像をサブディレクトリに抽出**（既定: `<出力MD basename>_images/`）
5. **出力ファイルをユーザーに報告**（最終 MD はセッションフォルダ直下、画像は同階層の `<basename>_images/`）
6. **venv 削除**

詳細な実行手順は [`references/procedures.md`](references/procedures.md)、環境構築は [`references/setup.md`](references/setup.md) を参照。

## スライド→Markdown の対応規則

| PPTX 要素 | Markdown 出力 |
|---------|-------------|
| 1 枚目のタイトル placeholder | `# <タイトル>` |
| 2 枚目以降のタイトル placeholder | `## <タイトル>` |
| タイトル placeholder が無いスライド | `## スライド<N>` |
| 本文 placeholder の段落 | 段落（空行区切り） |
| 本文 placeholder の箇条書き（レベル付き） | `-` インデント付き箇条書き（2 スペース／レベル） |
| 太字 / 斜体 / 取り消し線 | `**`, `*`, `~~` の Markdown 装飾 |
| モノスペースフォント段落（Consolas/Courier/Menlo 等） | コードブロック ```` ``` ```` |
| 表 (`shape.has_table`) | パイプ表（1 行目をヘッダ、無ければ自動付与） |
| 画像 (`MSO_SHAPE_TYPE.PICTURE`) | `![alt](<出力basename>_images/slide<N>_img<M>.<ext>)` |
| 図形 + コネクタのフロー | ```mermaid flowchart TD ... ``` |
| SmartArt（diagram XML） | ```mermaid flowchart ... ```（解析可能な範囲） |
| チャート (`shape.has_chart`) | 種別・系列名のメタ情報を `> チャート: ...` として出力 |
| スピーカーノート | `--include-notes` 指定時のみ `> [!NOTE]\n> ...` 形式 |
| 非表示スライド | `--include-hidden` 指定時のみ出力 |

## 出力の特徴

- UTF-8 / LF 改行で出力
- 画像はバイナリで抽出し、Markdown からは相対パスで参照
- Mermaid 化に失敗した図形は ```text``` 形式で「シェイプ種別・位置・テキスト」を残し、Claude が後段で再解釈できる情報を保持
- Claude のコンテキストに収まりやすいよう、視覚装飾は最小限に保つ

## アセットの場所

- 変換スクリプト: `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-from-pptx/convert_from_pptx.py`

## オプション

| オプション | 省略値 | 内容 |
|-----------|-------|------|
| `--images-dir <DIR>` | `<出力MD basename>_images/`（出力MDと同階層） | 画像抽出先ディレクトリ |
| `--no-mermaid` | OFF | フロー図 / SmartArt の Mermaid 変換を無効化（テキストフォールバック） |
| `--include-notes` | OFF | スピーカーノートを `> [!NOTE]` ブロックで含める |
| `--include-hidden` | OFF | 非表示スライドも出力に含める |
| `--no-first-slide-as-title` | ON（先頭を H1 扱い） | 指定時は 1 枚目も `## スライド1` として H2 扱い |
| `--max-image-size <BYTES>` | `5242880`（5 MiB） | 抽出する画像 1 枚あたりの最大サイズ。超過時はメタ情報のみ出力 |

## 重要な制約

- 画像出力先は出力 MD のディレクトリ配下に強制（パストラバーサル対策）
- 入力 PPTX は ZIP コンテナとしての妥当性を簡易検証（マジックバイト `PK\x03\x04`）してから python-pptx に渡す
- SmartArt は python-pptx が完全サポートしないため、`diagramData` 名前空間の XML を直接読み解く。解析できない構造はテキストフォールバック
- フロー図の Mermaid 化は「図形 + コネクタ」「SmartArt の階層」を対象とする。手書きの矢印などコネクタ要素として登録されていない接続は検出できない（テキストフォールバック）
- アニメーション・スライドマスター上の装飾・スライド遷移情報は破棄する
- 画像の `alt` 属性は picture shape の `name` / `description` から取得。両方ない場合は `image<連番>` を使用

## 参照

| 用途 | ファイル |
|-----|---------|
| 環境構築 | [`references/setup.md`](references/setup.md) |
| 変換実行手順 | [`references/procedures.md`](references/procedures.md) |
| 動作分岐の期待挙動ケース | [`evals/`](evals/) |
