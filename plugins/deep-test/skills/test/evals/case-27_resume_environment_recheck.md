<!-- TEST-ORCH-EVAL-R2-27-SENTINEL-v1 -->
# case-27 resume 時の環境再確認（ps + health 再確認 → healthy 再利用 / unhealthy down → up）

中断 run からの resume で、`environment.yaml` が applicable かつ `status.state: up` のまま残っている場合に、ps + health の再確認（`action=status`）を委譲し、**健全なら再利用（再 up 不要）・不健全なら down → up で作り直して**から残ケースを継続することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「resume」（または `/deep-test:test resume`） |
| 前提 | 中断 run が 1 件（in_progress / interrupted）。`environment.yaml` が存在し `applicability: applicable`・`status.state: up` のまま（down 未実施で中断）。Playwright MCP はロード済み |

## 分岐の根拠

references/flow.md 5.1 手順 6（environment.yaml が applicable の場合は環境を再確認する: `docker compose -p {slug}-test ps` + health 再確認〔`Skill: test-environment` の `action=status`〕で健全なら**再利用**〔再 up 不要〕・不健全なら `action=down` → `action=up` で作り直す）・5.2（中断時に environment が up のまま残っている場合、down は自動実施されていない。resume するなら手順 6 の環境再確認で再利用 / 作り直しを判定・resume しない場合は手動 down を案内）・5.1 手順 4〜8（resumable_runs の missing 採用・run_id 新規採番禁止・MCP ゲート再判定）、SKILL.md「引き渡し」（environment up 後の中断: resume 時は健全なら再利用される）。

## 期待動作

- Phase 0（target-slug 解決）を省略せず実施し、summary で中断 run を特定・`validate` の `resumable_runs` の `missing` を resume scope に採用する
- resume scope に Playwright 必要レベルが含まれる場合は MCP ゲートを再判定する
- environment.yaml が applicable のため `Skill(deep-test:test-environment)` に `action=status` を委譲し、ps + health の再確認結果を受領する（オーケストレータが推定で健全と見なさない）
- **healthy の場合**: 再利用する（`action=up` を再委譲しない・再 provision しない）。endpoints / project 名は既存 environment.yaml から読み、実行スキルへ渡す対象アプリ情報に用いる
- **unhealthy の場合**（対比動作）: `action=down` → `action=up` を順に委譲して作り直してから継続する
- `start-run` を実行せず（run_id 新規採番禁止）、中断 run の run_id で残ケースを実行スキルへ委譲 → record → finish-run で completed に確定する
- Phase 6（結果レビュー）PASS 後に `action=down` を委譲してから Phase 7 へ進む（ワンサイクルを resume 側で完結する）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（同一 run_id への record / finish-run。Edit / Write の直接編集なし）・environment.yaml の status 更新（status / down / up の各 action で test-environment が更新）・報告書 |
| 標準出力（要約） | 環境再確認の結果（再利用 or 作り直し）を含む resume 完了報告（SKILL.md「引き渡し」の正常フォーマット） |
| 終了状態 | 同一 run_id で finish-run → Phase 6 → down → Phase 7 完了（健全時は再 up なしで継続） |

## 関連ケース

- case-03: resume の本体（MCP ゲート停止からの復帰・run_id 引き継ぎ）
- case-25: 初回フローでの up（本ケースは中断後の再確認・再利用）
- case-26: NEEDS REVISION で維持された環境が up のまま残る文脈（中断すれば本ケースの前提になる）
