<!-- TEST-ENVIRONMENT-AGENTS-SENTINEL-v1 -->
# test-environment エージェント運用定義（フェーズ定義）

`test-environment` スキルが参加させるエージェントと、その動作フェーズを定義する。
エージェントの選定表・起動方式・プロンプト組み立て・共通注入事項・並列起動の原則は `${CLAUDE_PLUGIN_ROOT}/references/agents.md`（プラグイン共通の SSOT）が唯一の定義場所であり、本書はそれを本スキルの文脈に適用したフェーズ割り当てのみを定義する（規範本文は複製しない）。

---

## 1. 利用可能なエージェント一覧

エージェントはプラグインルート `agents/` に配置された共有定義を `subagent_type: "deep-test:<agent-name>"` 形式で参照する（随時追加されるため固定リストは持たない。スキル改修時に `agents/` 配下と `${CLAUDE_PLUGIN_ROOT}/references/agents.md` の選定表を確認する）。

## 2. このスキルで使用するエージェント

| ID | subagent_type | 役割 | 説明 |
|----|--------------|------|------|
| env | `deep-test:env-architect` | 派生環境設計の自己チェッカー | test-environment が生成した `environment.yaml` と派生成果物（`environment/compose.test.yml` / `environment/.env.test`）の**分離妥当性**（project / ports `!override` / volumes / networks）・**read-only 境界**（SUT・既存 docker 資産の無変更）・**秘匿値の非出力**（`.env` 複製なし・`config --quiet`）・**本番誤爆疑義**（外部接続突合）・**teardown 完全性**（`down -v`・残存確認・ログ保存）・スキーマ準拠を単独レビューする。テストケースの妥当性評価（test-architect / coverage-reviewer の責務）・実行結果の分析は対象外 |

- 本スキルは **env-architect のみ** を使用する（単独起動。並列起動はしない）
- 逆呼び出し禁止: test-environment は他 worker スキル（test-design / test-run-* 等）を呼ばない。env-architect と用途限定ツール（Read/Grep/Glob/Write/Bash〔docker・curl・date〕）のみを使用し、2 段委譲（コマンド → オーケストレータ → worker → エージェント）を厳守する

## 3. フェーズ定義

### Phase 1: 派生生成・検証（action=provision）
- **実行エージェント**: なし（本スキルが実施。手順は `${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 2〜7 章）
- **目的**: docker 資産の検出・`analysis.yaml` 消費・要否判定を経て、派生成果物（`environment/compose.test.yml` / `environment/.env.test`）を生成し、`config --quiet` で静的検証のうえ `environment.yaml` を出力する
- **入力**: target / base / project / levels・`analysis.yaml`（存在時は消費・非存在時は軽量補完）
- **出力**: `{base}/{target-slug}/environment/` 配下の派生成果物・`{base}/{target-slug}/environment.yaml`（no-op / 縮退時は `applicability` + `reason` のマニフェスト）

### Phase 2: 自己チェック
- **実行エージェント**: env（`deep-test:env-architect`）・**単独起動**
- **目的**: 派生設計の分離妥当性（project 名 / `ports: !override` / volume / network の非干渉）・read-only 境界（SUT・既存 docker 資産の無変更）・秘匿値の非出力（開発 `.env` の複製なし・`config --quiet` 遵守）・本番誤爆疑義（`external_dependencies` との突合結果）・teardown 完全性（`down -v --remove-orphans`・`ps` 残存確認・ログ保存の設計）・environment.yaml のスキーマ準拠を単独レビューする
- **入力**: `environment.yaml` / 派生成果物 / SUT の元 compose ファイル（read-only）の**解決済み絶対パス**・消費した `analysis.yaml` パス・`target_type` / `analysis_consumed`・共通注入事項ブロック（`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 4.3 章）
- **出力**: 指摘一覧（重要度・信頼度・対象・指摘内容・根拠・修正提案）と総合所見（PASS 相当 / NEEDS REVISION 相当の**意見**。最終判定は本スキル）

### Phase 3: 指摘反映
- **実行エージェント**: なし（本スキルが実施）
- **目的**: env-architect の重大指摘（read-only 境界の逸脱・秘匿値の混入・分離不備・本番誤爆疑義の未解消・teardown 不備）を成果物へ反映する。env-architect には評価のみをさせ、成果物の修正はさせない（反映は本スキルの責務。`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 冒頭の構造規範）
- **入力**: Phase 2 の指摘一覧・所見
- **出力**: 反映済みの `environment.yaml` / 派生成果物・反映不要と判断した指摘の理由（返却の所見に残す）

## 4. フェーズ運用のルール

- Phase 2 の env-architect 起動は Agent ツールで行い、プロンプトには共通注入事項ブロック（信頼度 0〜100 の付与・未確認を「問題なし」と書かない・severity は `severity-policy.md` 準拠・エビデンス要件は `evidence-policy.md` 準拠）を必ず含める
- 結果の統合・PASS / NEEDS REVISION の判断・成果物への反映可否は**起動元スキル（test-environment）の責務**。env-architect に総合判定や成果物修正をさせない
- Phase 2 → Phase 3 は重大指摘（read-only 境界の逸脱・秘匿値の混入等）が解消するまで繰り返してよいが、反映しない指摘は理由を付して返却の所見に残す（黙殺しない）
- no-op / 縮退判定（派生を生成せず `applicability` + `reason` のみのマニフェスト）の場合も、判定理由の妥当性を env-architect に確認させてよい（生成物が小さくても自己チェックを省略しない運用が望ましい）
- 自己チェックは provision（Phase 1.7）で必ず実施する。up / down / status のライフサイクル操作のみの起動では、成果物（派生設計）が変わらないため自己チェックを省略してよい（status.notes への記録のみで返却できる）
