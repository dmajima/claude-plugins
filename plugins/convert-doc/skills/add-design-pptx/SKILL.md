---
name: add-design-pptx
description: convert-pptx 用の新しいデザインテーマ（テーマ JSON）を検証付きで作成・配置するスキル。「PPTX のデザインを追加」「スライドの配色テーマを作って」「PowerPoint のテーマ追加」等で起動する。Use when creating a new design theme for Markdown-to-PPTX conversion. SKIP when adding an HTML/PDF design (add-design-html) or when just converting a document (convert-pptx).
---

# add-design-pptx スキル

convert-pptx が使う新しいデザインテーマ（テーマ JSON）を作成・検証・配置する。

## 責務

- デフォルトデザインをベースにした新テーマ JSON の生成
- テーマ JSON のスキーマ検証（`validate_theme.py`）
- サンプル Markdown での実変換による動作確認
- 配置先の自動判定（開発リポジトリ / 利用者環境）と配置

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| Markdown → PPTX 変換の実行 | `convert-pptx`（テーマ選択 UI を含む） |
| HTML / PDF 用デザインの追加 | `add-design-html` |
| 変換スクリプト（convert_pptx.py）自体の改修 | 本スキル外（プラグイン開発作業） |

## トリガー条件

- 「PPTX（スライド / PowerPoint）の新しいデザイン・テーマ・配色を追加して」等の自然言語依頼
- `/add-design-pptx` スラッシュコマンド

このスキルを起動しないケース:

- HTML / PDF のデザイン追加（→ `add-design-html`）
- 既存テーマを使った変換の実行（→ `convert-pptx`）

## 前提

- Python 3.9+ が利用可能
- 初回起動時はインターネット接続あり（python-pptx 等のパッケージインストール用）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| デザイン名と要件（色等）が引数で全指定 | 非対話 | 確認プロンプトなしで生成・検証・配置まで進行 |
| 上記以外（自然言語依頼・要件不足） | 対話 | デザイン名・コンセプト・配置先を `AskUserQuestion` で確認 |

## 実行フロー

1. **要件確定** — デザイン名（kebab-case、予約名 `default` / `template` 不可）とデザインコンセプト（配色・フォント等）を確定
2. **ワークディレクトリ作成** — `.claude/.local/work/yyyyMMdd_nn_add_design_pptx/{inputs,workspace}`
3. **venv 構築** — `workspace/.venv` 配下（[`references/setup.md`](references/setup.md)）
4. **デフォルトテーマ取得** — `convert_pptx.py --dump-default-theme` でベース値を取得
5. **テーマ JSON 生成** — [`references/theme-schema.md`](references/theme-schema.md) に従い `workspace/` に生成
6. **スキーマ検証** — `validate_theme.py` で検証。FAIL 時は修正して再検証
7. **サンプル変換** — サンプル MD を `--theme` 付きで実変換し PPTX 生成が成功することを確認
8. **配置** — [`../../references/design-locations.md`](../../references/design-locations.md) の判定で配置先を決定し、ユーザー確認のうえ配置
9. **使い方案内** — `convert-pptx` でのテーマ選択方法を提示
10. **venv 削除**

詳細手順は [`references/procedures.md`](references/procedures.md) を参照。

## アセットの場所

| アセット | 配置 |
|---------|------|
| テーマ検証スクリプト | `${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-pptx/validate_theme.py` |
| 変換スクリプト（デフォルト値の SSOT） | `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py` |
| 配置規約 | `${CLAUDE_PLUGIN_ROOT}/references/design-locations.md` |

## 重要な制約

- テーマ JSON は必ず `validate_theme.py` の PASS とサンプル変換の成功を確認してから配置する
- デザイン名に予約名（`default` / `template`）と既存テーマ名との重複を使わない（重複時は別名提案 or 上書き確認）
- `${CLAUDE_PLUGIN_ROOT}` 配下（プラグインキャッシュ）へ書き込まない。配置先は `design-locations.md` の判定に従う
- デフォルトデザインの変更（convert_pptx.py 内蔵値・既存テーマの無断編集）は行わない
- 中間生成物は `workspace/` に置き、配置前の最終テーマ JSON もセッション内で検証を完結させる

## 参照

| 用途 | ファイル |
|-----|---------|
| 環境構築（venv・依存パッケージ） | [`references/setup.md`](references/setup.md) |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| テーマ JSON スキーマ | [`references/theme-schema.md`](references/theme-schema.md) |
| デザイン配置規約（プラグイン共通） | [`../../references/design-locations.md`](../../references/design-locations.md) |
| 動作分岐の期待挙動ケース | [`evals/`](evals/) |
