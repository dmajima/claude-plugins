---
name: minutes-docx
description: |
  minutes-composer が生成した構造化議事録データ（JSON）を python-docx で docx（Word）ファイルに変換するスキル。
trigger:
  - '議事録の docx / Word 出力を依頼された場合'
  - 'minutes-composer の出力後に Word で出して 等の依頼'
---

# Minutes Docx

構造化議事録データ（JSON）を docx（Word）ファイルに変換するスキル。

## 責務

- minutes.json を読み込み、スタイル定義済みの Word テンプレートに流し込んで議事録 docx を生成する
- python-docx ライブラリを使用し、同梱の docx テンプレートに構造データを流し込む

## 責務外

- 議事録の構造化（minutes-composer が担当）
- データ取得（ailead-fetcher / transcript-converter が担当）

## トリガー条件

- minutes-composer による構造データ作成が完了し、docx 出力が必要な場合
- 議事録の Word 出力を依頼された場合

## 前提

- minutes-composer が出力した `minutes.json` がセッション作業領域の `workspace/` に存在すること
- python-docx パッケージが venv にインストール済みであること

## 重要な制約

- 議事録を Word 形式で配布・保管する業務要件に対応する。テンプレートベースでスタイルを統一する
- python-pptx と同様、Windows + PowerShell 環境では Start-Job 経由ラッパーでの起動が必要な場合がある

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| workspace/minutes.json が存在 | 非対話 | 自動で docx 生成 |
| minutes.json 不在 | 対話 | minutes-composer の実行を提案 |

## 概要

`minutes-composer` が生成した `minutes.json` を入力として、
`python-docx` ライブラリで議事録 Word ファイルを生成する。
スタイル定義済みのテンプレート（`.docx`）をベースとするため、
フォント・見出し・表のスタイルが統一される。

## 実行フロー

1. `minutes.json` をセッション作業領域の `workspace/` から読み込む
2. テンプレート `${CLAUDE_SKILL_DIR}/assets/template/minutes-template.docx` を読み込む
3. Python スクリプト `${CLAUDE_SKILL_DIR}/scripts/output/generate_docx.py` を実行する
4. 生成された `minutes.docx` をセッション直下に配置する

## 入力

| ファイル | 形式 | 説明 |
|---------|------|------|
| `workspace/minutes.json` | JSON | minutes-composer が出力した構造化議事録データ |

## 出力

| ファイル | 形式 | 説明 |
|---------|------|------|
| `minutes.docx` | docx | 完成した議事録 Word ファイル |

## テンプレートのスタイル定義

同梱テンプレート `assets/template/minutes-template.docx` に定義済みのスタイル:

| スタイル名 | 用途 | フォント/サイズ |
|-----------|------|--------------|
| Title | 会議タイトル | Meiryo / 18pt |
| Heading 1 | セクション見出し（議事内容・決定事項等） | Meiryo / 14pt |
| Heading 2 | 議題見出し | Meiryo / 12pt |
| Normal | 本文 | Meiryo / 10.5pt |
| List Bullet | 箇条書き | Meiryo / 10.5pt |
| Table Grid | 表 | Meiryo / 9pt |

## Python スクリプト

```bash
& chcp.com 65001 | Out-Null
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

& $venvPy "$CLAUDE_SKILL_DIR\scripts\output\generate_docx.py" \
  --input "$SESSION_DIR\workspace\minutes.json" \
  --template "$CLAUDE_SKILL_DIR\assets\template\minutes-template.docx" \
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
| 環境構築 | [`references/setup.md`](references/setup.md) |
| 生成手順 | [`references/procedures.md`](references/procedures.md) |
| docx テンプレート | [`assets/template/minutes-template.docx`](assets/template/minutes-template.docx) |
| JSON スキーマ | `${CLAUDE_PLUGIN_ROOT}/skills/minutes-composer/references/schema/minutes-schema.md` |
