# convert-from-pptx 実行手順

環境構築は `setup.md` を参照すること。

## 変換スクリプト実行

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_SKILL_DIR}/scripts/convert/convert_from_pptx.py" \
  "<入力PPTXファイルパス>" \
  "<出力MDファイルパス>" \
  [--images-dir <DIR>] \
  [--no-mermaid] \
  [--include-notes] \
  [--include-hidden] \
  [--no-first-slide-as-title] \
  [--max-image-size <BYTES>]
```

- 出力先が未指定の場合、入力ファイルと同ディレクトリ・同名で `.md` 拡張子
- `--images-dir` 未指定時は `<出力MD basename>_images/` を出力 MD と同階層に作成
- `--max-image-size` は 1 画像あたりのバイト上限（既定 5 MiB）。超過時はメタ情報のみ Markdown に残す

## スライド→Markdown 規則

| PPTX | Markdown |
|------|---------|
| 1 枚目のタイトル placeholder | `# <タイトル>` |
| 2 枚目以降のタイトル placeholder | `## <タイトル>` |
| タイトル placeholder 無し | `## スライド<N>` |
| 本文段落（テキストフレーム） | 段落（空行区切り） |
| 本文段落（箇条書きレベル付き） | `-` インデント（2 スペース／レベル） |
| 太字 / 斜体 / 取り消し線 | `**...**` / `*...*` / `~~...~~` |
| モノスペース段落 | ```` ``` ```` ブロック |
| 表 | パイプ表 |
| 画像 | `![alt](<basename>_images/slide<N>_img<M>.<ext>)` |
| 図形+コネクタ | Mermaid `flowchart` |
| SmartArt | Mermaid `flowchart`（解析可能な範囲） |
| チャート | `> チャート: <種別> 系列=[...]` |
| スピーカーノート | `> [!NOTE]\n> ...`（`--include-notes` 指定時） |

## convert_from_pptx.py の変換処理フロー

1. **入力検証** — 入力 PPTX の存在・拡張子・ZIP マジックバイトを確認
2. **出力パス検証** — 画像出力先が出力 MD ディレクトリ配下に解決されることを検証（パストラバーサル対策）
3. **PPTX 読込** — `pptx.Presentation(input_path)`
4. **スライド巡回** — `prs.slides` をインデックス付きで巡回
5. **タイトル抽出** — placeholder (`PP_PLACEHOLDER.TITLE`/`CENTER_TITLE`) から取得。無ければスライド番号
6. **shape 巡回** — placeholder 本文 / 表 / 画像 / グループ / SmartArt / チャート / コネクタを判別
7. **フロー図検出** — 同一スライド内の図形 + コネクタ（`shape_type == LINE` または `CONNECTOR`）を解析し、ノード集合とエッジを抽出
8. **Mermaid 生成** — `flowchart TD` を基本とし、レイアウト幅 > 高さの場合は `LR` に切替
9. **画像抽出** — `picture.image.blob` を `<basename>_images/slide<N>_img<M>.<ext>` に保存
10. **Markdown 組立** — 各スライドのブロックを `\n\n` で連結し、スライド境界で空行
11. **ファイル書き出し** — UTF-8 / LF

## ブロック要素のレンダリング

| 要素 | Markdown 表現 |
|------|-------------|
| 段落 | プレーンテキスト（複数の run は装飾を保持して結合） |
| 箇条書き | `-` インデント（pPr.lvl を尊重） |
| 見出し（H3+ に相当する強調段落） | `### <text>` |
| コードブロック（モノスペース） | ```` ```\n...\n``` ```` |
| 表 | パイプ表（ヘッダ行 + セパレータ + 本体行） |
| 画像 | `![<alt>](<相対パス>)` |
| Mermaid | ```mermaid\nflowchart TD\n...\n``` |
| チャート | 引用ブロック `> チャート: <type>` |
| スピーカーノート | 引用ブロック `> [!NOTE]\n> ...` |

## トラブルシューティング

| 症状 | 対応 |
|------|------|
| `Module not found: pptx` | `pip install python-pptx` が venv 内で行われているか確認 |
| `Error: Input file is not a valid PPTX (zip)` | 入力ファイルが本当に PPTX か確認。PPT (旧形式) や暗号化済みファイルは非対応 |
| 画像が `_images/` に出力されない | `--max-image-size` の上限を超過していないか、書き込み権限があるか確認 |
| Mermaid に変換されず原図形がテキストで残る | 図形がコネクタで接続されていないか、SmartArt の構造が複雑すぎる可能性。`--no-mermaid` で挙動を切り替えて差分を確認 |
| 日本語が文字化け | 出力は UTF-8（BOM なし）。読み込みエディタのエンコーディング設定を確認 |
| 大量の画像で生成が遅い | `--max-image-size` を下げる、または前段で不要画像を削除した PPTX に差し替える |
