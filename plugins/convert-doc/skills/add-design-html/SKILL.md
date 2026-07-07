---
name: add-design-html
description: convert-html / convert-pdf 用の新しいデザイン CSS を契約検証（JS 動作保証）付きで作成・配置するスキル。「HTML のデザインを追加」「新しい CSS テーマを作って」「資料の見た目を変えるデザイン追加」等で起動する。Use when creating a new design CSS for Markdown-to-HTML/PDF output. SKIP when adding a PPTX theme (add-design-pptx) or when just converting (convert-html / convert-pdf).
---

# add-design-html スキル

convert-html / convert-pdf が使う新しいデザイン（CSS、必要時は同名 HTML テンプレートのペア）を作成・検証・配置する。

## 責務

- デフォルト `template.css` をベースにした新デザイン CSS の生成
- セレクタ契約 + JS 契約の機械検証（`validate_css.py`）
- HTML 構造変更が必要なデザインに限る同名 HTML テンプレートのペア生成と検証（`validate_html.py`）
- サンプル Markdown での実変換による動作確認
- 配置先の自動判定（開発リポジトリ / 利用者環境）と配置

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| Markdown → HTML 変換の実行 | `convert-html`（CSS 選択 UI を含む） |
| Markdown → PDF 変換の実行 | `convert-pdf` |
| PPTX 用テーマの追加 | `add-design-pptx` |
| JS 機能の追加・変更 | `convert-html` の `references/js-authoring.md` に従う別作業 |

## トリガー条件

- 「HTML（ドキュメント / 資料）の新しいデザイン・テーマ・配色を追加して」等の自然言語依頼
- `/add-design-html` スラッシュコマンド

このスキルを起動しないケース:

- PPTX テーマの追加（→ `add-design-pptx`）
- 既存デザインを使った変換の実行（→ `convert-html` / `convert-pdf`）

## 前提

- Python 3.9+ が利用可能（検証スクリプトとサンプル変換用）
- 初回起動時はインターネット接続あり（依存パッケージインストール用）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| デザイン名と要件（配色等）が引数で全指定 | 非対話 | 確認プロンプトなしで生成・検証・配置まで進行 |
| 上記以外（自然言語依頼・要件不足） | 対話 | デザイン名・コンセプト・HTML 変更要否・配置先を `AskUserQuestion` で確認 |

## 実行フロー

1. **要件確定** — デザイン名（kebab-case、予約名 `template` / `default` 不可）・コンセプト・HTML 構造変更の要否を確定
2. **ワークディレクトリ作成** — `.claude/.local/work/yyyyMMdd_nn_add_design_html/{inputs,workspace}`
3. **venv 構築** — `workspace/.venv` 配下（[`references/setup.md`](references/setup.md)）
4. **ベース読込** — デフォルト `template.css`（+ HTML ペア生成時は `template.html`）と [`references/css-contract.md`](references/css-contract.md) を読み込む
5. **CSS 生成** — 契約セレクタを網羅した新デザイン CSS を `workspace/` に生成（HTML ペアが必要な場合は同名 `.html` も生成）
6. **機械検証** — `validate_css.py`（+ ペア時 `validate_html.py`）で検証。FAIL 時は修正して再検証
7. **サンプル変換** — サンプル MD を `--css-template`（+ ペア時 `--html-template`）付きで実変換し HTML 生成を確認
8. **配置** — [`../../references/design-locations.md`](../../references/design-locations.md) の判定で配置先を決定し、ユーザー確認のうえ配置
9. **使い方案内** — `convert-html` / `convert-pdf` でのデザイン選択方法を提示
10. **venv 削除**

詳細手順は [`references/procedures.md`](references/procedures.md) を参照。

## HTML 構造変更の原則

- **既定は CSS のみ**。HTML はデフォルト `template.html` を共用し、全デザインで JS 動作を同一に保つ
- CSS だけで表現できないデザイン（例: ヘッダーバー等の構造要素追加）に限り、同名 HTML テンプレートをペア生成する
- ペア HTML は **JS 契約に影響しない変更のみ許可**: 全プレースホルダの維持・骨格 DOM（`#wrap` / `#main-content` / `.doc-title` / `.article-body`）の維持を `validate_html.py` で強制する
- デフォルトの `template.html` / `template.css` 自体は変更しない（既存出力の構造不変を保証）

## アセットの場所

| アセット | 配置 |
|---------|------|
| CSS 検証スクリプト | `${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_css.py` |
| HTML 検証スクリプト | `${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_html.py` |
| ベース CSS（デフォルトデザイン） | `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css` |
| ベース HTML テンプレート | `${CLAUDE_PLUGIN_ROOT}/assets/html/template.html` |
| 変換スクリプト（サンプル変換用） | `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-html/convert.py` |
| 配置規約 | `${CLAUDE_PLUGIN_ROOT}/references/design-locations.md` |

## 重要な制約

- 新デザインは必ず `validate_css.py`（ペア時 `validate_html.py` も）の PASS とサンプル変換の成功を確認してから配置する
- JS 契約（[`references/css-contract.md`](references/css-contract.md) の REQUIRED 項目）を満たさない CSS を配置しない
- デザイン名に予約名（`template` / `default`）と既存デザイン名との重複を使わない（重複時は別名提案 or 上書き確認）
- `${CLAUDE_PLUGIN_ROOT}` 配下（プラグインキャッシュ）へ書き込まない。配置先は `design-locations.md` の判定に従う
- デフォルトの `template.css` / `template.html` および既存デザインを変更しない
- 中間生成物は `workspace/` に置く

## 参照

| 用途 | ファイル |
|-----|---------|
| 環境構築（venv・依存パッケージ） | [`references/setup.md`](references/setup.md) |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| セレクタ契約・JS 契約の全リスト | [`references/css-contract.md`](references/css-contract.md) |
| デザイン配置規約（プラグイン共通） | [`../../references/design-locations.md`](../../references/design-locations.md) |
| 動作分岐の期待挙動ケース | [`evals/`](evals/) |
