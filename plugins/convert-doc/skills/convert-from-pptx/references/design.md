# convert-from-pptx 設計方針

PPTX → Markdown 変換において、Python 単独でルールベースに装飾を判定する従来方式は、テンプレート構造の多様性により本文消失や装飾混入の誤検出が避けられない。本スキルは「機械抽出 + LLM 意味解釈」の 2 段階構成を採用する。

## 2 フェーズ構成

| フェーズ | 担当 | 役割 |
|---------|------|------|
| Phase 1 | Python（`convert_from_pptx.py`） | 全 shape の構造データを完全抽出して JSON に dump（装飾フィルタは適用しない） |
| Phase 2 | Claude メインコンテキスト | JSON を文脈解釈し、装飾とコンテンツを区別した Markdown を生成 |
| Phase 3 | Python + Claude（`verify_md.py`） | 生成 MD を元 PPTX と機械的に突き合わせて漏れ・誤転記を検証 |

## Claude メインコンテキストの責務

以下は Python 側ではなく Claude が判断する。

- 装飾フィルタリング（フッタ・ページ番号・凡例ラベルの除外）
- タイトル推定（placeholder 種別・幾何・フォントサイズの優先順位）
- フロー図の Mermaid 化（コネクタ駆動）
- 視覚順での要素並べ替え（top → left）
- 関係性（コネクタ・グループ・並列レイアウト）の Markdown 構造への反映

## スライド → Markdown の対応規則（Phase 2 ガイドライン）

| PPTX 要素 | Markdown 出力 |
|---------|-------------|
| 1 枚目のメインタイトル | `# <タイトル>` |
| 2 枚目以降のスライドタイトル | `## <タイトル>` |
| タイトルが推定できないスライド | `## スライド<N>`（最終手段） |
| 本文 placeholder の段落 | 段落（空行区切り） |
| 本文 placeholder の箇条書き | `-` インデント付き箇条書き（2 スペース／レベル） |
| 太字 / 斜体 / 取り消し線 | `**`, `*`, `~~` |
| モノスペースフォント段落 | コードブロック ` ``` ` |
| テーブル (`kind=TABLE`) | GFM パイプ表 |
| 画像 (`kind=PICTURE`) | `![alt](<basename>_images/slideN_imgM.<ext>)` |
| 図形群 + コネクタ | ```mermaid flowchart ... ``` |
| SmartArt | ```mermaid flowchart ... ```（解析可能な範囲） |
| チャート | `> チャート: ...` のメタ情報 |
| スピーカーノート | `--include-notes` 指定時のみ `> [!NOTE]\n> ...` |
| FOOTER / SLIDE_NUMBER placeholder | **出力しない**（テンプレ装飾） |
| `template_decoration_texts` 一致テキスト | **出力しない** |
| 凡例ラベル（薄いグレー / 極小フォント / 同テキスト 3 回以上） | **出力しない** |

## 関連

| 用途 | ファイル |
|-----|---------|
| 詳細な変換ロジック | [`procedures.md`](procedures.md) |
| JSON スキーマと Phase 2 解釈ガイド | [`json-schema.md`](json-schema.md) |
| Phase 3 検証ガイド | [`validation.md`](validation.md) |
| 大規模 PPTX のサイズ別フロー | [`large-pptx-workflow.md`](large-pptx-workflow.md) |
