# add-design-html

convert-html / convert-pdf（Markdown → HTML / PDF 変換）で使える **新しいデザイン** を追加するスキル。

## 概要

デフォルトの `template.css` をベースに新デザイン CSS を生成し、
セレクタ契約・JS 契約（DOM ID / 状態クラス / ブレークポイント）の機械検証とサンプル変換で
動作確認したうえで配置します。配置したデザインは `convert-html` 実行時の CSS 選択肢に自動的に現れ、
`convert-pdf` でも同じ資産が使われます。

HTML 構造・変換処理・JS 機能は全デザイン共通のまま **CSS だけを差し替える** 方式のため、
デザインを増やしても JS 機能のバグやデザインごとの動作不良が構造的に起きにくいのが特徴です。
CSS だけで表現できないデザインに限り、JS 契約を守った同名 HTML テンプレートをペアで持てます。

## このドキュメントについて

本ファイルは人間向けリファレンスであり、Claude のスキル動作では使用されません。
スキルの動作定義は `SKILL.md` と `references/` を参照してください。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法（マーケットプレイス経由 / ローカル複製 / 自動更新 / 依存パッケージ）は [`plugins/convert-doc/README.md`](../../README.md) の「導入手順」を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

依存パッケージ（検証用のサンプル変換で convert-html と同一の venv 依存を使用。検証スクリプト自体は標準ライブラリのみ）はスキル初回起動時に自動インストールされます。

## 使い方

トリガーフレーズ例:

- 「HTML 資料にダークテーマのデザインを追加して」
- 「ドキュメントの見た目のバリエーションを増やしたい」
- `/add-design-html`

流れ: デザイン名・コンセプト確定 → CSS 生成（必要時 HTML ペアも） → `validate_css.py` /
`validate_html.py` 検証 → サンプル変換 → 配置先確認 → 配置。

## 動作例

入力: 「温かみのある紙っぽいデザイン `warm-paper` を追加して」

出力（開発リポジトリ内での実行時）:

```
plugins/convert-doc/assets/css/warm-paper.css
```

利用者環境での実行時:

```
<repo>/.claude/.local/plugins/convert-doc/designs/css/warm-paper.css
```

以後 `convert-html` 実行時に「template / warm-paper」の選択肢が表示されます。
明示指定する場合:

```bash
python convert.py input.md output.html --css-template "<デザイン CSS の絶対パス>"
```

## カスタマイズ・拡張

- 守るべき契約の全リスト: `references/css-contract.md`（REQUIRED は `validate_css.py` が機械検証）
- 検証ロジック: `references/scripts/add-design-html/validate_css.py` / `validate_html.py`（プラグイン共通 scripts 配下）
- 配置場所の規約: `references/design-locations.md`（プラグイン共通）
- JS 機能そのものの追加は `convert-html` スキルの `references/js-authoring.md` を参照（本スキルの責務外）

## ファイル構成

```
skills/add-design-html/
├── SKILL.md                        # スキル定義（Claude が実行時に読む）
├── README.md                       # 本ファイル（人間向け）
├── references/
│   ├── procedures.md               # 実行手順詳細
│   ├── css-contract.md             # セレクタ契約・JS 契約の全リスト
│   └── setup.md                    # venv 構築・削除
└── evals/                          # 動作分岐の期待挙動ケース
    ├── README.md
    ├── demo.sh                     # デモ実行スクリプト
    └── case-01 〜 case-13
```

関連スクリプト（プラグイン共通）:

```
references/scripts/add-design-html/validate_css.py    # CSS 契約検証
references/scripts/add-design-html/validate_html.py   # HTML ペア検証
references/scripts/convert-html/convert.py            # 変換本体（--css-template / --html-template）
```
