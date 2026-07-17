# case-03 E2E テスト実行依頼（スコープ外明示）

ユーザーがユニットテストと E2E テストの実行を同時に依頼したケース。ユニットテストのみを対象とし、E2E / 結合 / ブラウザ / 性能テストをスコープ外として明示することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "ユニットテストと E2E テストを実行して結果を見せて" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |

## 分岐の根拠

SKILL.md「E2E・結合テストはスコープ外」の「`test-runner` が実行するのは ユニットテストのみ。E2E / 結合 / ブラウザテスト / 性能テストは本スキルの対象外」、references/checklist.md セクション B O4 / O8 およびセクション D の「O4 | E2E / 結合等のスコープ外指摘は本レポートから除外」、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 5（testing 行: E2E・性能テスト・脆弱性スキャン → 対象外）およびセクション 4（オーケストレーター不在時は本スキル自身で progress.md を作成・維持）。

## 期待動作

- ユニットテスト部分のみを test-runner の対象とし、実行可能なら実行・不能なら SKIPPED 記録する（SKILL.md「E2E・結合テストはスコープ外」「動的検証」）
- E2E テストは実行せず、本スキルの対象外（スコープ外）であることを明示する（checklist.md O4）
- E2E / 結合 / ブラウザ / 性能テストに関するスコープ外指摘を中間レポートに混入させない（checklist.md セクション D「O4」）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（checklist.md O8 / common-references.md セクション 4）
- test-engineer / test-runner の 1 メッセージ内並列起動は通常通り行う（checklist.md O1）
- 「別 PR で対応」「Issue を作成」等の文言を出力に含めない（checklist.md C-Auto-4 / universal-rules.md U8）

## 関連ケース

- case-01: ユニットテストのみの実行依頼（通常分岐）
