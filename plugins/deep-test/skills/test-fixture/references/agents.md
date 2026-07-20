<!-- TEST-FIXTURE-AGENTS-SENTINEL-v1 -->
# test-fixture エージェント運用定義（フェーズ定義）

`test-fixture` スキルが参加させるエージェントと、その動作フェーズを定義する。
エージェントの選定表・起動方式・プロンプト組み立て・共通注入事項・並列起動の原則は `${CLAUDE_PLUGIN_ROOT}/references/agents.md`（プラグイン共通の SSOT）が唯一の定義場所であり、本書はそれを本スキルの文脈に適用したフェーズ割り当てのみを定義する（規範本文は複製しない）。

---

## 1. 利用可能なエージェント一覧

エージェントはプラグインルート `agents/` に配置された共有定義を `subagent_type: "deep-test:<agent-name>"` 形式で参照する（随時追加されるため固定リストは持たない。スキル改修時に `agents/` 配下と `${CLAUDE_PLUGIN_ROOT}/references/agents.md` の選定表を確認する）。

## 2. このスキルで使用するエージェント

| ID | subagent_type | 役割 | 説明 |
|----|--------------|------|------|
| fix | `deep-test:fixture-architect` | フィクスチャ設計の自己チェッカー | test-fixture が生成 / 拡充した `fixtures.yaml` と SUT テストコードの設計妥当性・再利用性・責務分離（認証/モック/シード）・**書き込み境界の遵守**・**認証情報のハードコード有無**を単独レビューする。テストケースの妥当性評価（test-architect / coverage-reviewer の責務）・実行結果の分析は対象外 |

- 本スキルは **fixture-architect のみ** を使用する（単独起動。並列起動はしない）
- 逆呼び出し禁止: test-fixture は他 worker スキル（test-design / test-run-* 等）を呼ばない。fixture-architect と read-only + SUT テスト書き込みツールのみを使用し、2 段委譲（コマンド → オーケストレータ → worker → エージェント）を厳守する

## 3. フェーズ定義

### Phase 1: フィクスチャ生成 / 拡充
- **実行エージェント**: なし（本スキルが実施。手順は `${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2〜7 章）
- **目的**: `analysis.yaml` を消費し、既存基盤を検出して、認証 / モック / シード / base のフィクスチャと `playwright.config.ts` を生成 / 拡充し、`fixtures.yaml` を出力する
- **入力**: 対象説明 / target-slug / base / project・`analysis.yaml`（存在時は消費・非存在時は軽量補完）
- **出力**: SUT テストコード（`playwright.config.ts` / `{tests}/fixtures/*.ts` / `auth.setup.ts` / seed）・`{base}/{target-slug}/fixtures.yaml`（no-op 時は `fixtures: []` + 理由）

### Phase 2: 自己チェック
- **実行エージェント**: fix（`deep-test:fixture-architect`）・**単独起動**
- **目的**: 生成 / 拡充したフィクスチャ設計の妥当性・再利用性・責務分離（認証/モック/シードの分離）・**書き込み境界の遵守**（SUT テストディレクトリのみ・プロダクションコード不変）・**認証情報のハードコード有無**・fixtures.yaml のスキーマ準拠を単独レビューする
- **入力**: `fixtures.yaml` / 生成した SUT テストコードの**解決済み絶対パス**・消費した `analysis.yaml` パス・`target_type` / `analysis_consumed`・SUT テストディレクトリ・共通注入事項ブロック（`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 4.3 章）
- **出力**: 指摘一覧（重要度・信頼度・対象・指摘内容・根拠・修正提案）と総合所見（PASS 相当 / NEEDS REVISION 相当の**意見**。最終判定は本スキル）

### Phase 3: 指摘反映
- **実行エージェント**: なし（本スキルが実施）
- **目的**: fixture-architect の重大指摘を成果物へ反映する。fixture-architect には評価のみをさせ、成果物の修正はさせない（反映は本スキルの責務。`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 冒頭の構造規範）
- **入力**: Phase 2 の指摘一覧・所見
- **出力**: 反映済みの `fixtures.yaml` / SUT テストコード・反映不要と判断した指摘の理由（返却の所見に残す）

## 4. フェーズ運用のルール

- Phase 2 の fixture-architect 起動は Agent ツールで行い、プロンプトには共通注入事項ブロック（信頼度 0〜100 の付与・未確認を「問題なし」と書かない・severity は `severity-policy.md` 準拠・エビデンス要件は `evidence-policy.md` 準拠）を必ず含める
- 結果の統合・PASS / NEEDS REVISION の判断・成果物への反映可否は**起動元スキル（test-fixture）の責務**。fixture-architect に総合判定や成果物修正をさせない
- Phase 2 → Phase 3 は重大指摘（書き込み境界の逸脱・認証情報のハードコード等）が解消するまで繰り返してよいが、反映しない指摘は理由を付して返却の所見に残す（黙殺しない）
- no-op 判定（SUT へ書き込まず空 fixtures.yaml）の場合も、判定理由の妥当性を fixture-architect に確認させてよい（生成物が空でも自己チェックを省略しない運用が望ましい）
