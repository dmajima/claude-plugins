# add-design-pptx

convert-pptx（Markdown → PPTX 変換）で使える **新しいデザインテーマ** を追加するスキル。

## 概要

デフォルトデザインをベースに、色・フォント・フォントサイズ・レイアウト寸法・シンタックスハイライト配色に加え、
**構図（表紙・本文見出し部のレイアウト構造。`composition` セクション）** を差し替えたテーマ JSON を生成し、
スキーマ検証とサンプル変換で動作確認したうえで配置します。
配置したテーマは `convert-pptx` 実行時の選択肢に自動的に現れます。

変換パイプライン（`convert_pptx.py`）自体は共通のまま、テーマ JSON だけでデザインを切り替えるため、
デザインごとの動作不良が構造的に起きにくいのが特徴です。

## このドキュメントについて

本ファイルは人間向けリファレンスであり、Claude のスキル動作では使用されません。
スキルの動作定義は `SKILL.md` と `references/` を参照してください。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法（マーケットプレイス経由 / ローカル複製 / 自動更新 / 依存パッケージ）は [`plugins/convert-doc/README.md`](../../README.md) の「導入手順」を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

依存パッケージ（テーマ検証・サンプル変換で convert-pptx と同一の venv 依存を使用）はスキル初回起動時に自動インストールされます。

## 使い方

トリガーフレーズ例:

- 「PPTX にダークテーマを追加して」
- 「スライドの新しい配色テーマを作って」
- `/add-design-pptx`

流れ: デザイン名・コンセプト確定 → テーマ JSON 生成 → `validate_theme.py` 検証 →
サンプル変換 → 配置先確認 → 配置。

## 動作例

入力: 「コーポレートグリーン系の PPTX テーマ `corp-green` を追加して」

出力（開発リポジトリ内での実行時）:

```
plugins/convert-doc/assets/pptx-themes/corp-green.json
```

利用者環境での実行時:

```
<repo>/.claude/.local/plugins/convert-doc/designs/pptx-themes/corp-green.json
```

以後 `convert-pptx` 実行時に「デフォルト / corp-green」の選択肢が表示されます。
明示指定する場合:

```bash
python convert_pptx.py input.md output.pptx --theme "<テーマ JSON の絶対パス>"
```

## カスタマイズ・拡張

- テーマ JSON のスキーマ: `references/theme-schema.md`（構図 `composition` の仕様・既定構図リファレンス・executive 風の記述例を含む）
- デフォルト値の取得: `python convert_pptx.py --dump-default-theme`（構図は動的追従のため含まれない。既定構図は `theme-schema.md` を参照）
- 検証ロジック: `references/scripts/add-design-pptx/validate_theme.py`（プラグイン共通 scripts 配下）は
  `convert_pptx.py` の `load_theme` を直接使うため、スキーマ変更時の追従作業は不要
- 既定構図リファレンスの同期照合: `references/scripts/add-design-pptx/check_default_composition.py`
- 配置場所の規約: `references/design-locations.md`（プラグイン共通）

## ファイル構成

```
skills/add-design-pptx/
├── SKILL.md                        # スキル定義（Claude が実行時に読む）
├── README.md                       # 本ファイル（人間向け）
├── references/
│   ├── procedures.md               # 実行手順詳細
│   ├── theme-schema.md             # テーマ JSON スキーマ
│   └── setup.md                    # venv 構築・削除
└── evals/                          # 動作分岐の期待挙動ケース
    ├── README.md
    ├── demo.sh                     # デモ実行スクリプト
    └── case-01 〜 case-15
```

関連スクリプト（プラグイン共通）:

```
references/scripts/add-design-pptx/validate_theme.py             # テーマ検証
references/scripts/add-design-pptx/check_default_composition.py  # 既定構図リファレンス同期照合
references/scripts/convert-pptx/convert_pptx.py                  # 変換本体（--theme / --dump-default-theme）
```
