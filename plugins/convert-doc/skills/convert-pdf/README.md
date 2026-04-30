# convert-pdf スキル

Markdown を Wiki デザインの PDF に変換するスキル。`convert-doc` プラグインに同梱されている。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法はリポジトリルートの [`README.md`](../../../../README.md) を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

初回実行時に `scripts/setup/setup_venv.sh` が以下を自動で実行します。

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
  "${CLAUDE_SKILL_DIR}/scripts/convert/convert_pdf.py" \
  "<入力MD>" "<出力PDF>" [--title "タイトル"] [--format A4] [--landscape]
```

## ファイル構成

```
skills/convert-pdf/
├── SKILL.md
├── README.md
├── references/
│   ├── procedures.md
│   └── setup.md
└── scripts/
    ├── convert/
    │   └── convert_pdf.py
    └── setup/
        ├── requirements.txt
        ├── setup_venv.sh
        └── teardown_venv.sh
```

## カスタマイズ

- デザイン変更はプラグイン共通の `plugins/convert-doc/assets/css/template.css` を編集する（convert-html と共有）
  - convert-pdf だけに独自 CSS を適用したい場合は `skills/convert-pdf/assets/css/template.css` に上書きファイルを置くこともできるが、現在の `convert_pdf.py` は convert-html の convert.py を呼び出して HTML を生成するため、convert-html 側の解決ロジックに従う
- Playwright の PDF オプション（ヘッダー/フッター、印刷オプション）は `scripts/convert/convert_pdf.py` の `page.pdf(...)` 呼び出し箇所を編集する
