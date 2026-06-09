# templates/

拡張要素の新規作成時にコピー元として使用する **ひな形ファイル** を管理する。

## ファイル一覧

| サブフォルダ | 内容 |
|------------|------|
| `skill/` | スキルのひな形（SKILL.md・references/・evals/） |
| `plugin/` | プラグインのひな形（plugin.json・LICENSE・README.md） |
| `command/` | コマンドのひな形（frontmatter 付き .md） |
| `agent/` | エージェント・チームのひな形 |
| `hook/` | フックのひな形（hooks.json） |
| `marketplace/` | マーケットプレイスのひな形（marketplace.json） |
| `readme/` | README.md のひな形 |

## 利用ルール

- テンプレートは `*-toolkit` スキルがコピー・展開する。直接編集して成果物にしない
- テンプレート内の `{placeholder}` は展開時に置換される。プレースホルダの残存チェックは `run_checks.py` が担当
- テンプレート内の相対パス（`../../references/...`）は展開先で解決される。展開前の状態ではリンク切れが正常
- テンプレートの更新時は、対応する `*-toolkit` スキルの手順書も確認する
