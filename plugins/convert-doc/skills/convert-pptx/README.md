# convert-pptx スキル

Markdown を Wiki デザインの PowerPoint (PPTX) に変換するスキル。`convert-doc` プラグインに同梱されている。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

本スキルは `convert-doc` プラグインに同梱されています。プラグインのインストール方法（マーケットプレイス経由 / ローカル複製 / 自動更新 / 依存パッケージ）は [`plugins/convert-doc/README.md`](../../README.md) の「導入手順」を参照してください。

```text
/plugin install convert-doc@dmajima-claude-plugins
```

依存パッケージ（python-pptx / Pillow / requests / Pygments）は初回実行時に `references/scripts/setup/setup_venv.sh` が自動で venv を構築してインストールします。mermaid 図の取得には `mermaid.ink` への HTTPS 接続が必要です（オフライン環境ではテキストコードブロックにフォールバックします）。

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
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pptx/convert_pptx.py" \
  "<入力MD>" "<出力PPTX>" \
  [--title "主題"] [--subtitle "副題"] [--aspect 16:9] [--theme "<テーマJSONの絶対パス>"]
```

## 動作例

```text
ユーザ:
> 提案資料.md をスライドにして

Claude（要約）:
> テーマ選択: デフォルト / dark-console → デフォルトを選択
> 変換しました。出力: 提案資料.pptx（16:9・タイトルスライド + セクション別スライド）
```

## ファイル構成

```
skills/convert-pptx/
├── SKILL.md
├── README.md
├── evals/                    # 動作分岐の期待挙動ケース
└── references/
    ├── procedures.md
    ├── setup.md
    └── theme-selection.md    # デザインテーマの対話選択ルール
```

変換スクリプト・venv スクリプトはプラグイン共通の `references/scripts/`（プラグインルート直下）に配置:

```
references/scripts/
├── convert-pptx/
│   └── convert_pptx.py
└── setup/
    ├── requirements.txt
    ├── setup_venv.sh
    └── teardown_venv.sh
```

## カスタマイズ

- **色・フォント・サイズ・レイアウトの変更（推奨）**: `add-design-pptx` スキル（`/add-design-pptx`）でテーマ JSON を作成し `--theme` で適用する。既定値の一覧は `convert_pptx.py --dump-default-theme` で取得できる
- デフォルトデザイン自体の変更: `references/scripts/convert-pptx/convert_pptx.py` の `Theme` dataclass のフィールドデフォルトを編集する
- スライド分割規則の変更（例: H3 でもスライド分割する）は `split_into_slides` を編集する
- mermaid / 画像の最大サイズはテーマ JSON の `layout_in.mermaid_max_width` 等で変更できる
