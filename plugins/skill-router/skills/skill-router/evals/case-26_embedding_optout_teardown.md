# case-26 embedding optout teardown

埋め込み判定を有効から無効へ戻したとき、次の SessionStart で既存 venv が TTL によらず撤去されることを確認する変形ケース。約 650MB を伴う破壊的副作用を明示する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "埋め込みを無効に戻したのでディスクを解放したい" |
| 既存状態 | `<venv-base>/.venv` が構築済み / `<venv-base>/config.json` の `embedding.enabled` を `true` から `false` に変更済み / `.venv-last-used` は直前に更新されている（TTL 未超過） |
| モード | 自動（SessionStart 発火）・破壊的 |

## トリガープロンプト

```text
埋め込みを無効に戻したのでディスクを解放したい
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | SessionStart の `prepare` が `cleanup-if-stale` を実行する |
| 2 | `venv_required`（`embedding.enabled` かつ有効依存）が false と判定される |
| 3 | TTL を評価せずに `teardown()` を実行する（最終利用が直前でも撤去する） |
| 4 | `.venv` と `.venv-last-used` の両方が削除される |
| 5 | 続く `ensure` は `venv_required` が false のため何も構築しない |
| 6 | `python-bin` はシステム Python を返し、以降は heuristic のみで動作する |

## 期待出力

| 出力 | 内容 |
|-----|------|
| `<venv-base>/.venv` | 不在（約 650MB が解放される） |
| `<venv-base>/.venv-last-used` | 不在（`teardown` が併せて削除する） |
| `<venv-base>/venv-lifecycle.log` | `teardown removed=True path=<venv-base>/.venv` の行 |
| `index.json` | `stats.embedding.enabled=false`、`skills_vectorised=0` |
| `route_decisions.jsonl` | 以降の行は `"embedding_used": false` |
| ロック競合時 | 別セッションが `.venv.lock` を保持していれば撤去を見送り、`teardown skipped: lock held by another session` を記録する（次回 SessionStart で再試行） |

## 分岐の根拠

`references/scripts/routing/venv_lifecycle.py` の `cmd_cleanup_if_stale` は、venv が存在するのに `venv_required` が false の場合、TTL 判定より前に `teardown()` する。opt-out 後は venv に到達する経路が無くなるため、保持しても容量を占有するだけになる。

TTL 超過による撤去（case-24）とは契機が異なり、こちらは利用者の設定変更が直接のトリガーになる。撤去は無警告で行われるため、診断時に「勝手に消えた」と誤解されないよう挙動として明文化する。

## 関連ケース

- `case-13_embedding_disabled` — 既定（無効）では venv がそもそも構築されないこと
- `case-24_diag_prompt_hook_timeout` — TTL 超過による撤去と再構築の診断
- `case-25_venv_base_repo_isolation` — venv の探索先がリポジトリ配下を含まないこと

## 備考

- 依存定義（`requirements.txt`）が空になった場合も同じ経路で撤去される
- 再度有効化する場合は `<venv-base>/config.json` の `embedding.enabled` を `true` に戻す。次の SessionStart で `ensure` が再構築する（最大 240 秒）
- 単体テストでは `test_optout_removes_venv_regardless_of_ttl` と `test_no_active_requirements_removes_venv` が同じ分岐を固定している
