---
description: Markdown を Wiki スタイルの PDF に変換する
argument-hint: <入力MD> [出力PDF] [--title タイトル] [--format A4] [--landscape]
---

`convert-pdf` スキルを呼び出して Markdown を PDF に変換してください。

引数: $ARGUMENTS

## 実行手順

1. **引数の解釈**
   - 第1引数: 入力 Markdown ファイルパス（必須）
   - 第2引数: 出力 PDF ファイルパス（省略時はセッションフォルダ直下に `<元ファイル名>.pdf`）
2. **オプション**（任意・指定があればそのまま渡す）

   | オプション | 内容 |
   |-----------|------|
   | `--title <タイトル>` | ドキュメントタイトル |
   | `--format <用紙>` | `A4` / `A3` / `Letter` 等（既定 `A4`） |
   | `--landscape` | 横向きに切り替え |
   | `--margin <値>` | 余白（既定 `20mm`） |
   | `--no-background` | 背景色を印刷しない |
   | `--css-template <パス>` | デザイン CSS（省略時はデフォルト。追加デザインは `/add-design-html` で作成） |
   | `--html-template <パス>` | HTML テンプレート（デザインの同名ペアがある場合に指定） |

3. **Skill ツール経由で実行**

   ```
   Skill(skill: "convert-pdf", args: "<入力MD> <出力PDF> [オプション...]")
   ```

4. 完了後、出力ファイルの絶対パスをユーザーに報告する

## 注意

- 内部で `convert-html` を呼び出して HTML を生成し、Playwright (Chromium) で PDF 化する
- 初回実行時は Chromium のダウンロード（~120MB）が発生する
