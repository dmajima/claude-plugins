---
description: Markdown を Wiki スタイルの自己完結型 HTML に変換する（CSS / JS 機能を対話で選択）
argument-hint: <入力MDパス> [出力HTMLパス] [--title タイトル]
---

`convert-html` スキルを呼び出して Markdown を自己完結型 HTML に変換してください。

引数: $ARGUMENTS

## 実行手順

1. **引数の解釈**
   - 第1引数: 入力 Markdown ファイルパス（必須）
   - 第2引数: 出力 HTML ファイルパス（省略時はセッションフォルダ直下に `<元ファイル名>.html`）
   - `--title <タイトル>`: 任意。HTML の `<title>` と本文先頭の見出しに使用
2. **対話選択**は SKILL.md の通り実施
   - CSS が複数ある場合は `AskUserQuestion` で選択（`template.css`: ドキュメント型 / `executive.css`: Web ページ型・経営者向け）
   - JS 機能は `AskUserQuestion`（multiSelect）で除外したいものを選択
   - Web ページ型 CSS（`executive.css`）が選択された場合は、対の HTML 骨格と `--split-sections` を必ず併用する（ペアリング規則はスキルの `references/css-js-selection.md` を参照）
3. **Skill ツール経由で実行**

   ```
   Skill(skill: "convert-html", args: "<入力MD> <出力HTML> [--title <タイトル>] [--css-template <絶対パス>] [--html-template <絶対パス>] [--split-sections] [--js-features <カンマ区切り>]")
   ```

4. 完了後、出力ファイルの絶対パスをユーザーに報告する

## 注意

- 対話プロンプトが不要な場合は `/convert-html-full` を使用すること
- CSS / JS 機能の選択ルールの詳細は `convert-html` スキルの SKILL.md を参照
