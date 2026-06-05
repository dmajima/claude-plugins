---
name: minutes-md
description: |
  minutes-composer が生成した構造化議事録データ（JSON）を Markdown ファイルに変換するスキル。
trigger:
  - '議事録の md / Markdown 出力を依頼された場合'
  - 'minutes-composer の出力後に Markdown で出して 等の依頼'
---

# Minutes Md

構造化議事録データ（JSON）を Markdown ファイルに変換するスキル。

## 責務

- minutes.json を読み込み、議事録テンプレートに従った Markdown ファイルを生成する
- Python スクリプトでテンプレート準拠の一貫したフォーマットを保証する

## 責務外

- 議事録の構造化（minutes-composer が担当）
- データ取得（ailead-fetcher / transcript-converter が担当）

## トリガー条件

- minutes-composer による構造データ作成が完了し、Markdown 出力が必要な場合
- 議事録の Markdown 出力を依頼された場合

## 前提

- minutes-composer が出力した `minutes.json` がセッション作業領域の `workspace/` に存在すること

## 重要な制約

- minutes-docx と同様、minutes.json を入力とした変換に特化する。議事録の構造化は行わない

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| workspace/minutes.json が存在 | 非対話 | 自動で Markdown 生成 |
| minutes.json 不在 | 対話 | minutes-composer の実行を提案 |

## 概要

`minutes-composer` が生成した `minutes.json` を入力として、
Python スクリプトで議事録 Markdown ファイルを生成する。
`minutes-composer/references/template/minutes-template.md` と同一のフォーマットで出力する。

## 実行フロー

1. `minutes.json` をセッション作業領域の `workspace/` から読み込む
2. Python スクリプト `${CLAUDE_SKILL_DIR}/scripts/output/generate_md.py` を実行する
3. 生成された `minutes.md` をセッション直下に配置する

## 入力

| ファイル | 形式 | 説明 |
|---------|------|------|
| `workspace/minutes.json` | JSON | minutes-composer が出力した構造化議事録データ |

## 出力

| ファイル | 形式 | 説明 |
|---------|------|------|
| `minutes.md` | Markdown | 完成した議事録 Markdown ファイル |

## Python スクリプト

```bash
& chcp.com 65001 | Out-Null
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

& $venvPy "$CLAUDE_SKILL_DIR\scripts\output\generate_md.py" \
  --input "$SESSION_DIR\workspace\minutes.json" \
  --output "$SESSION_DIR\minutes.md"
```
## 参照

| 用途 | ファイル |
|-----|---------|
| 生成手順 | [`references/procedures.md`](references/procedures.md) |
| Markdown テンプレート（参考） | `${CLAUDE_PLUGIN_ROOT}/skills/minutes-composer/references/template/minutes-template.md` |
| JSON スキーマ | `${CLAUDE_PLUGIN_ROOT}/skills/minutes-composer/references/schema/minutes-schema.md` |
