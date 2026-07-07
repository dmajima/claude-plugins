---
name: convert-pptx
description: Markdown ファイルを Wiki スタイルの PowerPoint (PPTX) スライドに変換するスキル（入力 MD → 出力 PPTX）。「MD を PPTX に変換」「資料をスライドにして」「設計書を PPTX で出力」等で起動する。Use when converting Markdown into PPTX slides. SKIP when input is PPTX (convert-from-pptx), output is HTML/PDF (convert-html/convert-pdf), or a new theme (add-design-pptx).
---

# convert-pptx スキル

Markdown ファイルを Wiki デザインの PowerPoint (PPTX) に変換する。

## 責務

- Markdown → PPTX への変換（16:9 ワイドスクリーンが既定）
- `# タイトル` をタイトルスライドに、各 `## セクション` を新規スライドに分割
- 段落・箇条書き・コードブロック・表・mermaid 図・画像のスライド配置
- 1 スライドあたりの最大文字数を超える場合の継続スライド自動分割

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| HTML への変換 | `convert-html` |
| PDF への変換 | `convert-pdf` |
| PPTX → Markdown の取り込み（逆方向） | `convert-from-pptx` |
| 新しいデザインテーマの作成・追加 | `add-design-pptx`（本スキルは既存テーマの選択・適用のみ） |
| 完全なレイアウト保証（自動分割時の崩れ防止） | 本スキルではベストエフォート |

## トリガー条件

- 「MD を PowerPoint に変換」「資料をスライドにして」「設計書を PPTX で出力」等の自然言語依頼
- `/convert-pptx` スラッシュコマンド
- 他スキルからの `Skill(skill: "convert-pptx", ...)` 呼び出し

このスキルを起動しないケース:

- HTML / PDF への変換依頼（`convert-html` / `convert-pdf` へルーティング）
- 入力が PPTX（PPTX → Markdown は `convert-from-pptx` へルーティング）
- 新しいデザインテーマの追加依頼（`add-design-pptx` へルーティング）

## 前提

- 入力 Markdown ファイルがローカルに存在し読み取り可能
- Python 3.9+ が利用可能
- mermaid 図を含む場合はインターネット接続必要（オフライン時はテキストコードブロックにフォールバック）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `/convert-pptx` または自然言語依頼 | 通常（対話） | 16:9 ワイドスクリーン。追加テーマが存在する場合はテーマ選択 UI を提示 |
| `--aspect 4:3` / `--primary-color` / `--theme` 等の指定 | カスタム | 指定されたアスペクト比・色・テーマで処理 |
| 別スキルからの `Skill(...)` 呼び出し | 非対話 | テーマ選択 UI を出さずデフォルトデザイン（または引数指定テーマ）で処理 |

## 実行フロー

1. **ワークディレクトリ作成**（`.claude/.local/work/yyyyMMdd_nn_convert_pptx/{inputs,workspace}`）
2. **venv 構築**（`workspace/.venv` 配下）→ 依存パッケージをインストール
3. **テーマの選択**（対話モード時のみ・追加テーマが存在する場合のみ。詳細は [`references/theme-selection.md`](references/theme-selection.md)）
4. **変換スクリプト実行**（`references/scripts/convert-pptx/convert_pptx.py`）
5. **出力ファイルをユーザーに報告**（最終 PPTX はセッションフォルダ直下）
6. **venv 削除**

詳細な実行手順は [`references/procedures.md`](references/procedures.md)、環境構築は [`references/setup.md`](references/setup.md) を参照。

## スライド分割規則

| Markdown | 出力スライド |
|---------|-------------|
| 最初の `# タイトル` | タイトルスライド（1 枚目） |
| H1 が 1 つもない | タイトルスライドを生成しない（本文スライドのみ） |
| 各 `## セクション` | 新規スライドの先頭 |
| `### / #### / ...` | 同一スライド内の小見出し |
| H2 が 1 つもない | 全文を 1 枚の「本文スライド」に配置（タイトルなし） |

## 出力の特徴

- 16:9 ワイドスクリーン
- タイトル帯にネイビー（#003879）を使用
- コードブロックはモノスペースフォントのテキストフレーム
- 表は PowerPoint ネイティブの表（行/列選択・編集可能）
- mermaid 図は PNG として取得してスライドに配置
- 画像はローカルファイル・HTTP(S) いずれも対応

## アセットの場所

- 変換スクリプト: `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py`
- 追加デザインテーマ: `${CLAUDE_PLUGIN_ROOT}/assets/pptx-themes/*.json` およびローカルデザインディレクトリ（`${CLAUDE_PLUGIN_ROOT}/references/design-locations.md`）。新規追加は `add-design-pptx` スキルが担当

## オプション

| オプション | 省略値 | 内容 |
|-----------|-------|------|
| `--title` | MD 内の最初の H1 | タイトルスライドの主題 |
| `--subtitle` | なし | タイトルスライドの副題 |
| `--aspect` | `16:9` | スライドのアスペクト比（`16:9` または `4:3`） |
| `--primary-color` | テーマの primary（デフォルトテーマは `#003879`） | タイトル帯・見出しの基調色（`#RGB` または `#RRGGBB`）。テーマ指定より優先 |
| `--max-body-chars` | `2400` | 1 スライドあたりの本文最大文字数（超過時は継続スライドに自動分割） |
| `--theme` | なし（内蔵デフォルトデザイン） | デザインテーマ JSON のパス（部分指定でデフォルトを上書き） |
| `--dump-default-theme` | — | 内蔵デフォルトテーマを JSON で標準出力して終了（テーマ作成の起点） |

## 重要な制約

- mermaid 図の取得には `mermaid.ink` への HTTPS 接続が必要。オフライン時はテキストのコードブロック表示にフォールバック
- 1 スライドを超える長さのコンテンツは自動で継続スライドに分割するが、レイアウトの完全性は保証しない（ベストエフォート）
- 画像 URL は HTTP(S) のみ許可。プライベート IP（`127.0.0.1`、`10.0.0.0/8`、`192.168.0.0/16` 等）の IP リテラルへの接続は SSRF 対策として拒否する。ホスト名指定の解決可否は実行環境のファイアウォール / DNS ポリシーに委譲する（意図的なトレードオフ）
- ローカル画像パスは `base_dir` 配下に解決されることを検証する（パストラバーサル対策）
- mermaid.ink のレスポンスは Content-Type が `image/png` で、かつ PNG マジックバイト（`\x89PNG`）で始まることを検証してから埋め込む
- `--primary-color` は `#RGB` または `#RRGGBB` 形式のみ受理（不正値は `argparse.ArgumentTypeError` で拒否）

## 参照

| 用途 | ファイル |
|-----|---------|
| 環境構築 | [`references/setup.md`](references/setup.md) |
| 変換実行手順 | [`references/procedures.md`](references/procedures.md) |
| テーマの対話選択ルール | [`references/theme-selection.md`](references/theme-selection.md) |
| 動作分岐の期待挙動ケース | [`evals/`](evals/) |
