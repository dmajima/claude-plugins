# convert-pptx スキル

Markdown を Wiki デザインの PowerPoint (PPTX) に変換するスキル。`convert-doc` プラグインに同梱されている。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法はリポジトリルートの [`README.md`](../../../../README.md) を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

依存パッケージ（python-pptx / Pillow / requests / Pygments）は初回実行時に `scripts/setup/setup_venv.sh` が自動で venv を構築してインストールします。mermaid 図の取得には `mermaid.ink` への HTTPS 接続が必要です（オフライン環境ではテキストコードブロックにフォールバックします）。

## 仕組み

1. 入力 Markdown を行ベースでパース
2. `#` 見出しからタイトルスライドを構築
3. `##` 見出しごとに新規スライドを作成
4. 各スライドのコンテンツ領域にブロック要素（段落・箇条書き・コードブロック・表・mermaid・画像）を順番に配置
5. mermaid 図は `mermaid.ink/img/{base64url}?type=png` で PNG を取得して埋め込み
6. `python-pptx` で PPTX として保存

## 使い方

### 自然言語

- 「この設計書を PowerPoint にして」
- 「MD をスライドに変換」

### スクリプト直接実行

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_SKILL_DIR}/scripts/convert/convert_pptx.py" \
  "<入力MD>" "<出力PPTX>" \
  [--title "主題"] [--subtitle "副題"] [--aspect 16:9]
```

## ファイル構成

```
skills/convert-pptx/
├── SKILL.md
├── README.md
├── references/
│   ├── procedures.md
│   └── setup.md
└── scripts/
    ├── convert/
    │   └── convert_pptx.py
    └── setup/
        ├── requirements.txt
        ├── setup_venv.sh
        └── teardown_venv.sh
```

## カスタマイズ

- 色・フォント・レイアウトの調整は `scripts/convert/convert_pptx.py` 冒頭の定数（`PRIMARY`, `BODY_FONT`, `CODE_FONT`, `SLIDE_WIDTH_IN`, `SLIDE_HEIGHT_IN` など）を編集する
- スライド分割規則の変更（例: H3 でもスライド分割する）は `split_into_slides()` を編集する
- mermaid の PNG サイズは `MERMAID_MAX_WIDTH_IN` / `MERMAID_MAX_HEIGHT_IN` を変更する
