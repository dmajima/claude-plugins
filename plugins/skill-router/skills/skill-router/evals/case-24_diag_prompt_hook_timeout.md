# case-24 diag prompt hook timeout

ユーザが「プロンプト送信時に `UserPromptSubmit` フックがタイムアウトする」と訴える状況に対し、skill-router スキルが診断フローを実行する正例。case-07（SessionStart の遅延）と対になる、プロンプト経路側の診断ケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "UserPromptSubmit hook timed out after 30s と出てスキル推奨が効かない" |
| 既存状態 | `<base>/route.log` に直近のルーティング記録あり / `<venv-base>/.venv-last-used` の有無は環境依存 / `<venv-base>/venv-construct.log` は構築失敗時のみ存在 / `<venv-base>/.venv-construct-failed` はバックオフ中のみ存在 / `<venv-base>/.venv.lock` は他セッションが構築中のみ存在 |
| モード | 対話・診断 |

## トリガープロンプト

```text
UserPromptSubmit hook timed out after 30s と出てスキル推奨が効かない
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | skill-router スキルが起動する（high または mid 帯） |
| 2 | `hooks/hooks.json` の `UserPromptSubmit` の `timeout` を Read で確認する（現行仕様は 30。これを下回る値ならプラグイン更新が未反映） |
| 3 | `<venv-base>/config.json` の `embedding.enabled` を確認する。false（既定）なら venv 構築は発生しないため、以降の venv 系分岐は除外する |
| 4 | `<venv-base>/.venv-last-used` と `<venv-base>/.venv/pyvenv.cfg` の mtime を取得する。両者が近接し、かつタイムアウト時刻の直前であれば同一セッションで venv 構築が走っている |
| 5 | `<venv-base>/venv-construct.log`・`<venv-base>/.venv-construct-failed`・`<venv-base>/.venv-rebuild-count`・`<venv-base>/.venv.lock` を確認し、構築失敗・バックオフ・再構築予算・他セッションとの競合を判定する |
| 6 | `<base>/error.log` に `[route_prompt] interpreter=... rc=...` 行があるか確認する（プロンプト経路の失敗はここに残る） |
| 7 | `<base>/sessions/<sid>/prompts.jsonl` と `<base>/sessions/<sid>/route_decisions.jsonl` を突き合わせる。両者は 1 行ずつ対応する（推奨に至らなかったターンも `tier: "skip"` として決定側に残る）ため、`prompts.jsonl` にあり `route_decisions.jsonl` に無い行が中断されたプロンプト |
| 7b | `route_decisions.jsonl` の `elapsed_ms` を確認する。`over_budget: true` の行はソフト予算（1.5 秒）を超えて埋め込み補正を見送ったターンであり、タイムアウトの前段階の兆候として扱う |
| 8 | `<base>/index.json` の `stats.total_skills_indexed` と `<base>/inverted_index.json` のサイズから index 規模を確認する |
| 9 | 原因を切り分けて対処方針を提示する |

## 期待出力

| ケース | 提示内容 |
|-------|---------|
| **初回構築** | 「`embedding.enabled: true` で venv が未構築のため、SessionStart の `ensure` が構築（作成 60 秒 + pip install 180 秒 = 最大 240 秒）を実行しており、その間のプロンプトが競合しました。構築完了後は再発しません」 |
| **TTL 超過による再構築** | 「最終利用から `venv.ttl_hours`（既定 168 時間）を超えたため SessionStart の先頭で venv が撤去され、同一セッションの `ensure` が再構築しました。継続して利用している間は発生しません」 |
| **env-error 起因の再構築** | 「壊れた venv を検出して再構築が走りました。`.venv-rebuild-count` は SessionStart の `prepare` が毎回リセットするため通常は 1 で頭打ちになる。手動実行で 3 に達した場合は再構築予算を使い切っており、以降は再構築されずシステム Python で heuristic 専用のインデックスが生成されます（`stats.embedding.enabled=false`）。Claude Code を再起動するとカウンタがリセットされます」 |
| **構築失敗のバックオフ中** | 「`venv-construct.log` に失敗が記録され、`.venv-construct-failed` の `count` が 3 に達しています。以後 6 時間は `ensure` が構築を試みません（毎セッション 240 秒を消費しないための抑止）。ネットワーク到達性、またはプラットフォーム向け wheel の有無を確認してください」 |
| **他セッションが構築中** | 「`<venv-base>/.venv.lock` が存在します。別ウィンドウが構築または撤去を実行中で、こちらの `construct` は何もせず諦めます（ロックは 10 分で失効）。相手の完了を待ってください」 |
| **マーカー未生成** | 「`.venv-last-used` が存在しません。次回 SessionStart の `cleanup-if-stale` が既存 venv を採用してマーカーを生成します（この経路で撤去されることはありません）。即時に生成する場合は `venv_lifecycle.py touch-last-used` を実行してください」 |
| **撤去の部分失敗** | 「`.venv` は残存しているのに `pyvenv.cfg` が欠落しています。由来不明の状態として次回 SessionStart の `cleanup-if-stale` が撤去するため、Claude Code の再起動で解消します」 |
| **timeout 値が未更新** | 「`hooks.json` の `timeout` が 30 未満です。プラグインが更新されていません。`/plugin` でバージョンを確認し、更新後に Claude Code を再起動してください」 |
| **index の肥大化** | 「`stats.total_skills_indexed` が {N}、`inverted_index.json` が {S} と大きく、スコアリングの所要が増えています。`enabledPlugins` の削減、または `max_postings_per_keyword` の調整を検討してください」 |
| **ソフト予算超過が継続** | 「`route_decisions.jsonl` に `over_budget: true` が連続しています。`elapsed_ms` が 1500 を超えており、埋め込み補正が毎回見送られています。index 規模の削減、またはモデルキャッシュの事前配置を検討してください」 |
| **正常範囲** | 「フック実行は 30 秒予算に対し十分な余裕があります（`elapsed_ms` の実測は {N} ミリ秒）。単発の競合であり対応は不要です」 |

## 分岐の根拠

`hooks/hooks.json` の `UserPromptSubmit.timeout`（現行 30）と、`references/scripts/routing/venv_lifecycle.py` の TTL 判定（`venv_idle_seconds` が `<venv-base>/.venv-last-used` の mtime を基準とし、構築時刻とのクロスチェックを行う）。

プロンプト経路がタイムアウトする主因は、SessionStart 側で走る venv 構築との競合である。構築が走る契機は「初回構築」「TTL 超過後の再構築」「env-error 起因の `rebuild`」の 3 つがあり、それぞれ参照するファイルが異なる。さらに「バックオフ中で構築が走らない」「他セッションのロック待ち」という構築が進まない側の分岐もあるため、状態ファイルを個別に確認して切り分ける必要がある。

`embedding.enabled` が false（既定）の場合は venv 自体が構築されないため、これらの分岐はすべて除外され、原因は index 規模かプラグイン未更新に絞られる。

フックは fail-open のためプロンプト自体はブロックされないが、当該プロンプトの `additionalContext`（スキル推奨）が失われる点をユーザに説明する必要がある。

## 関連ケース

- `case-07_diag_slow_start` — SessionStart 側の遅延診断（本ケースはプロンプト経路側）
- `case-05_diag_no_recommendation` — 推奨が出ない場合の切り分け（タイムアウトも原因の 1 つ）
- `case-10_fail_open` — フェイルオープン挙動そのものの確認
- `case-13_embedding_disabled` — 既定（埋め込み無効）では venv 構築が発生しないこと
- `case-25_venv_base_repo_isolation` — venv の探索先がリポジトリ配下を含まないこと
- `case-22_ambiguous_intent_interactive` — 症状が不明な場合の入口

## 備考

- `<venv-base>` は `<base>` と解決順が異なる。`<base>` は `CLAUDE_PLUGIN_DATA` → リポジトリルート → ホームだが、`<venv-base>` は `CLAUDE_PLUGIN_DATA` → ホームのみでリポジトリ層を含まない。venv 系のファイルを `<base>` 側で探すと、リポジトリ内セッションでは存在しないパスを見ることになる
- 同義表現として「hook がタイムアウトする」「プロンプト送信時にエラーが出る」「output discarded と表示される」等もカバーする。表示される秒数は導入済みのバージョンによって異なる
- プロンプト経路の Python プロセス起動は 1 回（`route.py` のみ）。インタプリタ選択は Bash 側の `skill_router_venv_python` が行い Python を起動しない
- `<base>/index.log` の `duration_ms` は SessionStart 側のインデックス構築所要であり、プロンプト経路の実行時間ではない。index 規模の推定にのみ用いる
- SessionStart 側の env-error 判定は一時ファイル経由で行われ、その stderr は判定後に破棄される。`<base>/error.log` に残るのはプロンプト経路の記録（`[route_prompt] interpreter=... rc=...`）と、`build_index.py` / `route.py` が自ら記録した traceback
- TTL は `<venv-base>/config.json` の `venv.ttl_hours` で上書きできる（既定 168・下限 1 時間）。`embedding` ブロックも同じく `<venv-base>` が所有する
- `.venv-last-used` は mtime のみを判定に使う。初回作成時に説明文を書き込み、以降の更新は `os.utime()` によるメタデータ操作のみとなる
