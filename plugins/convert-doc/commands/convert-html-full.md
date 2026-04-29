---
description: Markdown を Wiki スタイル HTML に変換する（全 JS 機能有効・対話プロンプトなし）
argument-hint: <入力MDパス> [出力HTMLパス] [--title タイトル]
---

`convert-html` スキルを **対話プロンプトを一切出さずに、全機能有効** で呼び出してください。

引数: $ARGUMENTS

## 実行ルール（MANDATORY）

- **CSS の選択プロンプトは出さない**
  - プラグイン共通の `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css` を使用する（既定）
  - スキル側に `${CLAUDE_SKILL_DIR}/assets/css/template.css` が存在する場合はそちらが優先される（解決はスキル側のロジックに委ねる）
  - `--css-template` を明示する必要はない（SKILL.md の解決ロジックで自動選択）
- **JS 機能の選択プロンプトは出さない**
  - `--js-features` オプションを **省略** することで `features.json` 記載の全機能が有効になる
  - 「全て不要」「除外」等の問い合わせは行わない
- ユーザーへの追加確認は行わず、そのまま変換を進める

## 実行手順

1. 第1引数を入力 Markdown ファイルパスとして扱う
2. 第2引数があれば出力 HTML ファイルパス、なければセッションフォルダ直下に `<元ファイル名>.html`
3. `--title <タイトル>` があればそのまま渡す
4. **AskUserQuestion を呼び出さない**
5. Skill ツール経由で実行

   ```
   Skill(skill: "convert-html", args: "<入力MD> <出力HTML> [--title <タイトル>]")
   ```

6. 完了後、出力ファイルの絶対パスをユーザーに報告する

## 用途

- 自動化・バッチ処理など対話が困難な状況
- 全 JS 機能（ライトボックス・目次トグル等）を確実に含めたい場合
- ファイルサイズより機能優先の運用
