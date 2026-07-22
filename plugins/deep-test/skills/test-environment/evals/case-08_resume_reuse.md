<!-- TEST-ENVIRONMENT-EVAL-08-SENTINEL-v1 -->
# case-08 resume / retest 時の再利用（ps + health 再確認で健全なら再 up 不要）

中断からの resume / retest で、起動済み環境（`status.state: up / healthy`）に対し `action=status` の再確認を行い、**健全なら再 up せず再利用**する分岐を検証する。不健全なら down → up で作り直す対も固定する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web base=<base> action=status --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` の resume 復帰手順から。MCP ゲート再判定の直後の環境再確認） |
| 前提 | 前セッションで up 済み・down 未実施（`status.state: up` のまま中断）。コンテナは稼働継続中で health も到達可能 |

## 分岐の根拠

SKILL.md「action 分岐」（status = resume / retest の再利用判定・健全なら再 up 不要）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 8.3 章（status 手順・再利用判定: 健全なら再利用〔再 up 不要〕・不健全なら down → up）・9 章縮退表 9〜10 行目（中断ハンドオフは `status.state: up` のまま・resume 時に再利用判定）、`${CLAUDE_PLUGIN_ROOT}/skills/test/references/flow-resume.md` 5.2 章（resume 時は環境再確認で再利用 / 作り直しを判定・resume しない場合は手動 down 案内）。オーケストレータ側の起動条件は同 flow-resume.md 6 章 Phase 1.7 節（run-only / retest / resume では provision 済み environment.yaml があれば up / down のライフサイクル呼出のみ）。

## 期待動作

- 既存の `{base}/{target-slug}/environment.yaml` を Read し、`lifecycle` のコマンド規約形（up と同一 `-f` 群 + `-p`）を取得する（推定でコマンドを組み立てない）
- 共通プレフィクス + `ps` でコンテナの稼働状態を実測し、`endpoints[]` の 127.0.0.1 base URL へ curl で health を再確認する
- **健全な場合**: 再 up・再 provision を行わず、`status`（`state: healthy`・`last_action: status`・`last_action_at`）のみ更新して「再利用可能（再 up 不要）」を返却する
- **不健全な場合**（対比動作）: down → up の作り直しを提案し（非対話では down → up を実施）、実測に基づいて status を更新する
- 派生成果物（compose.test.yml / .env.test）は再生成しない（provision 済みの成果物を再利用する）
- 返却にテスト続行の材料（endpoints の health・start-run --environment 材料）を含める

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | environment.yaml の `status` 更新のみ（`state: healthy`・`last_action: status`・notes に ps / health の実測結果） |
| 標準出力（要約） | 環境構築結果サマリ（再利用可能〔再 up 不要〕・ps / health の実測結果・resume 続行の材料） |
| 終了状態 | 再 up せず status 更新のみで正常終了（冪等な状態確認） |

## 関連ケース

- case-07: 初回 up（本ケースは 2 回目以降の再確認）
- case-06: health 不健全時の扱い（本ケースの不健全分岐は down → up）
- case-09: 中断後に再利用せず片付ける選択（単独 down）
