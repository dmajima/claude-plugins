---
description: PowerPoint (PPTX) を Claude が読み込める Markdown に変換する
argument-hint: <入力PPTXパス> [出力MDパス] [--images-dir DIR] [--no-mermaid] [--include-notes]
---

`convert-from-pptx` スキルを呼び出して PowerPoint (PPTX) を Markdown に変換してください。

引数: $ARGUMENTS

## 実行手順

1. **引数の解釈**
   - 第1引数: 入力 PPTX ファイルパス（必須）
   - 第2引数: 出力 MD ファイルパス（省略時は入力ファイルと同階層に `<元ファイル名>.md`）
2. **オプション**（任意・指定があればそのまま渡す）

   | オプション | 内容 |
   |-----------|------|
   | `--images-dir <DIR>` | 画像抽出ディレクトリ（既定: `<出力MD basename>_images/`） |
   | `--no-mermaid` | 図形+コネクタや SmartArt の Mermaid 化を抑制 |
   | `--include-notes` | スピーカーノートを `> [!NOTE]` ブロックで含める |
   | `--include-hidden` | 非表示スライドも出力に含める |
   | `--no-first-slide-as-title` | 1 枚目を `## スライド1` として H2 扱い |
   | `--max-image-size <BYTES>` | 1 画像あたりの最大バイト数（既定 5 MiB） |

3. **Skill ツール経由で実行**

   ```
   Skill(skill: "convert-from-pptx", args: "<入力PPTX> <出力MD> [オプション...]")
   ```

4. 完了後、出力 MD と画像ディレクトリの絶対パスをユーザーに報告する

## 変換規則

| PPTX | Markdown |
|------|---------|
| 1 枚目のタイトル | `# <タイトル>` |
| 2 枚目以降のタイトル | `## <タイトル>` |
| 本文段落 | 段落 / 箇条書き（レベル保持） |
| 表 | パイプ表 |
| 画像 | `![alt](<basename>_images/slide<N>_img<M>.<ext>)` |
| 図形+コネクタ | Mermaid `flowchart` |
| SmartArt | Mermaid `flowchart`（解析可能な範囲） |
| モノスペース段落 | コードブロック |
| スピーカーノート | `> [!NOTE]`（オプション） |

## 注意

- 本スキルはオフラインで動作する（外部 API へのアクセスなし）
- 画像出力先は出力 MD と同階層の `<basename>_images/` に限定される（パストラバーサル対策）
- SmartArt の複雑な構造（マトリクス・サイクル等）は完全には Mermaid 化されない場合がある
