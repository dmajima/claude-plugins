<!-- TEST-ENVIRONMENT-EVAL-02-SENTINEL-v1 -->
# case-02 levels=unit のみの no-op（環境不要・委譲前抑制と起動時の自己限定）

見込みテストレベルが unit のみの対象に対し、docker 資産の有無に関わらず**環境不要**として no-op で正常終了する分岐を検証する。委譲前のオーケストレータ側抑制（スキップ）と、起動された場合のスキル側自己限定（二重抑制）の両方を固定する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=calc-lib project=./ base=<base> action=provision levels=unit --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.7。本来は委譲前にスキップされるが、起動された場合の自己限定を検証） |
| 前提 | `project=` 配下に `docker-compose.yml` が存在する（資産はある）。`analysis.yaml` 存在（target_type=library・UI 経路なし）。`levels=unit` のみ |

## 分岐の根拠

SKILL.md「責務 1」（`levels=` が unit のみなら no-op）・「前提」の引数表（`levels=` は環境要否判定の材料）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 5 章（unit のみ → 環境不要。MCP ゲートの「unit のみ判定不要」と同型）・9 章縮退表 2 行目（委譲前にオーケストレータでも抑制・生成しない or not-applicable）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 12 章（levels=unit のみ = 影響なし）。オーケストレータ側の抑制は R12 設計 4.3 章（フルフローでのみ委譲・unit のみ / design-only / report-only はスキップ）。

## 期待動作

- `levels=unit`（unit のみ）を検出し、docker 資産が存在しても**環境不要**と判定する（資産の有無より levels 判定が先行してよい）
- 派生成果物を生成せず、docker の起動系コマンド（up 等）を実行しない
- `applicability: not-applicable` + `reason`（例: 「levels=unit のみのため派生環境は不要」）のマニフェストを出力する（委譲スキップされた場合は生成自体が行われない）
- 非対話でも確認なしで no-op を確定する（曖昧確認をしない）
- unit の実行（test-run-unit）はホストのテストランナーで従来どおり行われ、run 側 status に影響しないことを返却で明示する
- no-op 判定（levels=unit のみ）の理由の妥当性も env-architect に確認させてよい（`${CLAUDE_SKILL_DIR}/references/agents.md` 4 章）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/environment.yaml`（`not-applicable` + reason）のみ、または委譲スキップ時は生成なし。`environment/` 配下は生成しない |
| 標準出力（要約） | 環境構築結果サマリ（applicability=not-applicable〔levels=unit のみ〕・派生なし・run 側影響なし） |
| 終了状態 | 派生・起動を行わず正常終了（非破壊 no-op） |

## 関連ケース

- case-01: 資産なしによる no-op（判定理由の違い）
- case-07: unit 以外を含む levels で非対話 up まで進む対
