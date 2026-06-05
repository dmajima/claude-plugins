# Minutes Md

構造化議事録データ（JSON v2.0）を Markdown ファイルに変換するスキル。

## このドキュメントについて

このファイルは人間向けリファレンスであり、Claude の動作では使用されない。
Claude は `SKILL.md` および `references/` 配下を参照する。

## 使い方

### トリガーフレーズ例

- 「議事録を Markdown で出力して」
- 「md 形式で保存して」
- 「Markdown 版を生成して」

### 入力 → 出力

| 入力 | 出力 |
|------|------|
| `workspace/minutes.json` | `minutes.md`（セッション直下） |

## 動作例

```
ユーザー: 「議事録を Markdown で出力して」

Claude:
1. workspace/minutes.json を確認
2. generate_md.py を実行
3. minutes.md をセッション直下に生成
4. ユーザーにファイルを提示
```

## カスタマイズ・拡張

### 出力フォーマットの変更

`scripts/output/generate_md.py` の各 `render_*` 関数を編集する。

| 関数 | 対象 |
|------|------|
| `render_agenda` | 議題セクションのレイアウト |
| `render_action_items` | アクションまとめのレイアウト |
| `render_next_meeting` | 次回予定のレイアウト |
| `format_participants` | 参加者一覧のフォーマット |

### テンプレート参照

Markdown テンプレートの定義は `minutes-composer` スキルに含まれる:
`skills/minutes-composer/references/template/minutes-template.md`

## ファイル構成

```
skills/minutes-md/
├── SKILL.md                    # スキル定義
├── README.md                   # 本ファイル（人間向け）
├── references/
│   └── procedures.md           # 生成手順
└── scripts/
    └── output/
        └── generate_md.py      # Markdown 生成スクリプト
```
