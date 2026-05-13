# skill-router skill

skill-router プラグインの **操作・診断ガイド** スキル。Claude Code が利用者の自然言語要求から `/router-*` コマンドへ誘導したり、`<base>/` 配下のインデックス・ログ・disabled フラグを Read で要約してユーザに状態を共有する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキルの動作本体は `SKILL.md` および `evals/` 配下、ロジック実装は `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/` 配下を参照してください。

## ディレクトリ構成

```text
skills/skill-router/
├── SKILL.md            # スキル定義（Claude Code が実行時に読み込む）
├── README.md           # このファイル（人間向け）
└── evals/              # 動作分岐検証用ケース集（21 ケース）
    ├── README.md       # ケース一覧・実行確認方法
    ├── case-01_rebuild.md                              # 操作系: /router-rebuild 案内
    ├── case-02_status.md                               # 操作系: /router-status 案内
    ├── case-03_disable.md                              # 操作系: /router-toggle off
    ├── case-04_skip_negative.md                        # 自動: skip_phrase 発火（負例）
    ├── case-05_diag_no_recommendation.md               # 診断: 推奨なし切り分け
    ├── case-06_diag_over_recommendation.md             # 診断: 過剰推奨切り分け
    ├── case-07_diag_slow_start.md                      # 診断: 起動遅延切り分け
    ├── case-08_toggle_on.md                            # 操作系: /router-toggle on
    ├── case-09_non_interactive.md                      # 操作系: 非対話モード
    ├── case-10_fail_open.md                            # 自動: フェイルオープン
    ├── case-11_embedding_cache_hit.md                  # 埋め込み: キャッシュヒット
    ├── case-12_embedding_boost_reorder.md              # 埋め込み: スコア再ソート
    ├── case-13_embedding_disabled.md                   # 埋め込み: 無効化フォールバック
    ├── case-14_cache_tamper_failopen.md                # 埋め込み: キャッシュ改竄検出
    ├── case-15_max_path_fallback.md                    # 埋め込み: Windows MAX_PATH 自動フォールバック
    ├── case-16_router_embedding_cache_modes.md         # 操作系: /router-embedding-cache 統計表示
    ├── case-17_router_embedding_cache_clear_noninteractive.md # 操作系: --clear 非対話
    ├── case-18_router_embedding_cache_show.md          # 操作系: --show 単一スキル
    ├── case-19_air_gapped_model_dl_failure.md          # 埋め込み: エアギャップ DL 失敗
    ├── case-20_embedding_model_switch.md               # 埋め込み: モデル切替時の全件無効化
    └── case-21_entries_sha256_tamper.md                # 埋め込み: entries_sha256 改竄検出
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
| コマンド | `../../commands/router-rebuild.md` / `router-status.md` / `router-toggle.md` / `router-embedding-cache.md` |
| evals | `evals/README.md` |
