<!-- TEST-ENVIRONMENT-EVAL-09-SENTINEL-v1 -->
# case-09 単独 down（コマンド起動・logs 保存 → down -v --remove-orphans → ps 残存確認）

`/deep-test:test-environment action=down` によるコマンド単独起動で、run 外の片付け（中断後の残存コンテナの撤収）を行う分岐を検証する。logs 保存 → down → 残存確認の teardown 完全性と、run_id 不在時のログ保存先（`environment/logs/{timestamp}/`）を固定する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | `/deep-test:test-environment action=down target=orderapp-web`（または「テスト用コンテナ環境を片付けて」） |
| 起動形態 | 単独（コマンド → スキル。対話・`run-id=` なし） |
| 前提 | 前セッションの中断で `{slug}-test` プロジェクトのコンテナが残存（`status.state: up` のまま）。environment.yaml は存在し `lifecycle.down_command` を保持 |

## 分岐の根拠

commands/test-environment.md（委譲型コマンド・action=down の単独運用は中断後の片付けに有用）、SKILL.md「責務 7」（logs 保存 → down -v --remove-orphans〔up と同一 -f 群 + -p に固定〕→ ps 残存確認 → status 更新）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 8.2 章（down 手順: logs が down より先・run_id なしは `environment/logs/{timestamp}/`・external volume の非削除記録）・8.5 章（中断ハンドオフの手動 down と同一のコマンド形）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 10.1 章（down は up と同一の `-f` 群 + `-p` を必ず付与・`-p` 単独 down のラベル解決に依存しない）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 5 章（ログ保存時のマスキング）。

## 期待動作

- コマンドは起動とバトン渡しに徹し、down のロジックはスキル側が実行する（コマンド側で複製しない）
- 既存 environment.yaml の `lifecycle.down_command` を Read で取得する（推定でコマンドを組み立てない）
- **down より先に**サービス別 logs を取得し、`run-id=` 不在のため `environment/logs/{timestamp}/{service}.log` へ保存する（マスキング適用）
- `down -v --remove-orphans` を **up と同一の `-f` 群 + `-p {slug}-test`** で実行する（named / anonymous volume は削除・external volume は削除されないため notes に記録）
- 共通プレフィクス + `ps` で残存ゼロを実測確認し、結果を `status.notes` に記録する（残存があれば notes へ残し手動対処を案内）
- `status` を更新する（`state: down`・`last_action: down`・`last_run_id: null`）
- SUT の docker 資産・開発環境側のコンテナ（`-p` 既定の開発プロジェクト）には触れない（分離名前空間の外へ影響しない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `environment/logs/{timestamp}/{service}.log`（マスキング適用）・environment.yaml の `status` 更新（`state: down`・notes に ps 残存確認結果・external volume の有無） |
| 標準出力（要約） | 環境構築結果サマリ（down 完了・logs 保存先・ps 残存確認 = なし・external volume の扱い） |
| 終了状態 | 撤収完了・残存ゼロを実測確認して正常終了（`{slug}-test` プロジェクトの残存コンテナがない） |

## 関連ケース

- case-06: run 中の health 未達に伴う down（本ケースは run 外の単独片付け）
- case-07: up 側のワンサイクル（run 中は `evidence/{run_id}/environment/` へ保存する対）
- case-08: 片付けず再利用する選択（resume 時の対）
