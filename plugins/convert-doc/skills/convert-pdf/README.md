# convert-pdf スキル

Markdown を Wiki デザインの PDF に変換するスキル。`convert-doc` プラグインに同梱されている。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法（マーケットプレイス経由 / ローカル複製 / 自動更新 / 依存パッケージ）は [`plugins/convert-doc/README.md`](../../README.md) の「導入手順」を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

初回実行時に `references/scripts/setup/setup_venv.sh` が以下を自動で実行します。

1. `playwright / markdown / Pygments / rcssmin / rjsmin / Pillow` のインストール
2. `playwright install chromium` による Chromium バイナリのダウンロード（~120MB）

`PLAYWRIGHT_BROWSERS_PATH` 環境変数で Chromium キャッシュを共有すると、再ダウンロードを避けられます。詳細は `references/setup.md` を参照。

## 仕組み

1. 入力 Markdown を同一プラグイン内の `convert-html` スキルで HTML 化（自己完結型 HTML）
2. Playwright の Chromium で生成 HTML を読み込み
3. `page.pdf(...)` で PDF を出力

すべての変換処理は HTML 側で行うため、mermaid・シンタックスハイライト・表などのデザインは **HTML 版と一致** する。

## 使い方

### 自然言語

- 「MD を PDF に変換して」
- 「この設計書を PDF で出力して」

### スクリプト直接実行

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pdf/convert_pdf.py" \
  "<入力MD>" "<出力PDF>" [--title "タイトル"] [--format A4] [--landscape] \
  [--css-template "<デザインCSSの絶対パス>"]
```

## 動作例

```text
ユーザ:
> 設計書.md を PDF にして

Claude（要約）:
> convert-html 経由で中間 HTML を生成し、Chromium で PDF 化しました。
> （追加デザインがある環境では、変換前にデザイン選択を確認します）
> 出力: 設計書.pdf（A4 縦・背景色印刷あり）
```

## ファイル構成

```
skills/convert-pdf/
├── SKILL.md
├── README.md
├── evals/                    # 動作分岐の期待挙動ケース
└── references/
    ├── procedures.md
    └── setup.md
```

変換スクリプト・venv スクリプトはプラグイン共通の `references/scripts/`（プラグインルート直下）に配置:

```
references/scripts/
├── convert-pdf/
│   └── convert_pdf.py
└── setup/
    ├── requirements.txt
    ├── setup_venv.sh
    └── teardown_venv.sh
```

## カスタマイズ

- **新しいデザインの追加（推奨）**: `add-design-html` スキル（`/add-design-html`）を使う。convert-html と共有の CSS 資産として追加され、`--css-template` パススルーで PDF にも適用できる
- デフォルトデザイン自体の変更はプラグイン共通の `plugins/convert-doc/assets/css/template.css` を編集する（convert-html と共有）
- Playwright の PDF オプション（ヘッダー/フッター、印刷オプション）は `references/scripts/convert-pdf/convert_pdf.py` の `page.pdf(...)` 呼び出し箇所を編集する
