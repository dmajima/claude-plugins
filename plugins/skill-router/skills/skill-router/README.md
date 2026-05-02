# skill-router skill

skill-router プラグインの **操作・診断ガイド** スキル。Claude Code が利用者の自然言語要求から `/router-*` コマンドへ誘導したり、`<base>/` 配下のインデックス・ログ・disabled フラグを Read で要約してユーザに状態を共有する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキルの動作本体は `SKILL.md` および `evals/` 配下、ロジック実装は `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/` 配下を参照してください。

## ディレクトリ構成

```text
skills/skill-router/
├── SKILL.md            # スキル定義（Claude Code が実行時に読み込む）
├── README.md           # このファイル（人間向け）
└── evals/              # 動作分岐検証用ケース集
    ├── README.md       # ケース一覧・実行確認方法
    ├── case-01_rebuild.md
    ├── case-02_status.md
    ├── case-03_disable.md
    └── case-04_skip_negative.md
```

実行ロジックはプラグイン直下の `references/scripts/lib/` に集約されており、本スキル内には Python ソースを置かない（ADR-024 / ADR-025 準拠）。

## 起動の仕組み

skill-router スキル自体は description ベースの AI 自動トリガーで起動する。代表的なトリガーフレーズ:

- 「skill-router の状態を見たい」「ルータの統計が知りたい」
- 「インデックスを再構築して」
- 「skill-router を一時停止」「ルーティングを切って」
- 「ルータのログを確認したい」「どのスキルが推奨されたか見たい」

## 関連リソース

| リソース | パス |
|---------|------|
| プラグイン README | `../../README.md` |
| ルーティング本体 | `../../references/scripts/lib/route.py` |
| インデクサ | `../../references/scripts/lib/build_index.py` |
| 設定既定値 | `../../references/templates/config.default.json` |
| コマンド | `../../commands/router-rebuild.md` / `router-status.md` / `router-toggle.md` |
| evals | `evals/README.md` |
