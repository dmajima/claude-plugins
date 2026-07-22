<!-- TEST-ANALYZE-AGENTS-SENTINEL-v1 -->
# test-analyze エージェント運用定義（フェーズ定義）

`test-analyze` スキルが参加させるエージェントと、その動作フェーズを定義する。
エージェントの選定表・起動方式・プロンプト組み立て・共通注入事項・並列起動の原則は `${CLAUDE_PLUGIN_ROOT}/references/agents.md`（プラグイン共通の SSOT）が唯一の定義場所であり、本書はそれを本スキルの文脈に適用したフェーズ割り当てのみを定義する（規範本文は複製しない）。

---

## 2. このスキルで使用するエージェント

| ID | subagent_type | 役割 | 説明 |
|----|--------------|------|------|
| src | `deep-test:source-analyst` | 解析材料の自己チェッカー | test-analyze が生成した `analysis.yaml` / `target-analysis.md` の網羅性・根拠妥当性・誠実性を単独レビューする。テスト計画 / ケースの妥当性評価（test-architect の責務）・実行結果の分析は対象外 |

- 本スキルは **source-analyst のみ** を使用する（単独起動。並列起動はしない）
- 逆呼び出し禁止: test-analyze は他 worker スキル（test-design / test-review 等）を呼ばない。source-analyst と read-only ツールのみを使用し、2 段委譲（コマンド → オーケストレータ → worker → エージェント）を厳守する

## 3. フェーズ定義

### Phase 1: 材料生成
- **実行エージェント**: なし（本スキルが実施。手順は `${CLAUDE_SKILL_DIR}/references/procedures.md` 2〜6 章）
- **目的**: テスト対象の read-only 静的理解から `analysis.yaml`（機械可読）と `target-analysis.md`（人間可読）を生成する
- **入力**: 対象説明 / target-slug / spec / diff / base・`source_availability` 判定結果
- **出力**: `{target-slug}/analysis.yaml` / `{target-slug}/target-analysis.md`

### Phase 2: 自己チェック
- **実行エージェント**: src（`deep-test:source-analyst`）・**単独起動**
- **目的**: 材料そのものの網羅性（EP / 依存 / ホットスポット / テスタビリティ / リスク / ISO 25010:2023 の 9 品質特性の抜け）・根拠妥当性（`source_ref` の具体性・`measured: false` と `null` の誠実な併用・`open_questions` への未確認事項記録・捏造の不在）・縮退整合・責務境界（`suggested_focus` が hint に留まるか）・スキーマ準拠を単独レビューする
- **入力**: `analysis.yaml` / `target-analysis.md` の**解決済み絶対パス**・`target_type` / `source_availability`・要件 / 仕様への参照・共通注入事項ブロック（`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 4.3 章）
- **出力**: 指摘一覧（重要度・信頼度・対象・指摘内容・根拠・修正提案）と総合所見（PASS 相当 / NEEDS REVISION 相当の**意見**。最終判定は本スキル）

### Phase 3: 指摘反映
- **実行エージェント**: なし（本スキルが実施）
- **目的**: source-analyst の重大指摘を材料へ反映する。source-analyst には評価のみをさせ、材料の修正はさせない（反映は本スキルの責務。`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 冒頭の構造規範）
- **入力**: Phase 2 の指摘一覧・所見
- **出力**: 反映済みの `analysis.yaml` / `target-analysis.md`・反映不要と判断した指摘の理由（返却の所見に残す）

## 4. フェーズ運用のルール

- Phase 2 の source-analyst 起動は Agent ツールで行い、プロンプトには共通注入事項ブロック（`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 4.3 章）を必ず含める
- 結果の統合・判定は起動元スキルの責務（`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 3 章・5 章）。材料への反映可否も本スキルが判断し、source-analyst に材料修正をさせない
- Phase 2 → Phase 3 は重大指摘が解消するまで繰り返してよいが、反映しない指摘は理由を付して返却の所見に残す（黙殺しない）
