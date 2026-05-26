---
name: minutes-docx
description: |
  minutes-composer が生成した構造化議事録データ（JSON）を docx（Word）ファイルに変換するスキル。
  What: minutes.json を読み込み、スタイル定義済みの Word テンプレートに流し込んで議事録 docx を生成する。
  Where: セッション作業領域に minutes.docx を出力する。
  When: minutes-composer による構造データ作成が完了し、docx 出力が必要な場合。
  Why: 議事録を Word 形式で配布・保管する業務要件に対応する。テンプレートベースでスタイルを統一する。
  How: python-docx ライブラリを使用し、同梱の docx テンプレートに構造データを流し込む。
  責務外: 議事録の構造化（minutes-composer が担当）。データ取得（ailead-fetcher / teams-fetcher が担当）。
trigger:
  - 議事録の docx / Word 出力を依頼された場合
  - minutes-composer の出力後に「Word で出して」等の依頼
---

# Minutes Docx

構造化議事録データ（JSON）を docx（Word）ファイルに変換するスキル。

## 概要

`minutes-composer` が生成した `minutes.json` を入力として、
`python-docx` ライブラリで議事録 Word ファイルを生成する。
スタイル定義済みのテンプレート（`.docx`）をベースとするため、
フォント・見出し・表のスタイルが統一される。

## 実行フロー

1. `minutes.json` をセッション作業領域から読み込む
2. テンプレート `${CLAUDE_SKILL_DIR}/assets/template/minutes-template.docx` を読み込む
3. Python スクリプト `${CLAUDE_SKILL_DIR}/scripts/output/generate_docx.py` を実行する
4. 生成された `minutes.docx` をセッション直下に配置する

## 入力

| ファイル | 形式 | 説明 |
|---------|------|------|
| `minutes.json` | JSON | minutes-composer が出力した構造化議事録データ |

## 出力

| ファイル | 形式 | 説明 |
|---------|------|------|
| `minutes.docx` | docx | 完成した議事録 Word ファイル |

## テンプレートのスタイル定義

同梱テンプレート `assets/template/minutes-template.docx` に定義済みのスタイル:

| スタイル名 | 用途 | フォント/サイズ |
|-----------|------|--------------|
| Title | 会議タイトル | Yu Gothic UI / 18pt |
| Heading 1 | セクション見出し（議事内容・決定事項等） | Yu Gothic UI / 14pt |
| Heading 2 | 議題見出し | Yu Gothic UI / 12pt |
| Normal | 本文 | Yu Gothic UI / 10.5pt |
| List Bullet | 箇条書き | Yu Gothic UI / 10.5pt |
| Table Grid | 表 | Yu Gothic UI / 9pt |

## Python スクリプト

```powershell
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$venvPy = "$SESSION_DIR\workspace\.venv\Scripts\python.exe"
& $venvPy "${env:CLAUDE_SKILL_DIR}\scripts\output\generate_docx.py" `
  --input "$SESSION_DIR\minutes.json" `
  --template "${env:CLAUDE_SKILL_DIR}\assets\template\minutes-template.docx" `
  --output "$SESSION_DIR\minutes.docx"
```

## 依存

| パッケージ | バージョン | 用途 |
|-----------|----------|------|
| `python-docx` | >=1.1.0 | Word ファイル生成 |

プラグイン共有の `references/scripts/setup/requirements.txt` に含まれている。

## 参照

| 用途 | ファイル |
|-----|---------|
| 生成手順 | [`references/procedures.md`](references/procedures.md) |
| docx テンプレート | [`assets/template/minutes-template.docx`](assets/template/minutes-template.docx) |
| JSON スキーマ | `skills/minutes-composer/references/schema/minutes-schema.md` |
