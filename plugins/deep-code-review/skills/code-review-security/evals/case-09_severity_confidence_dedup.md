# case-09 重要度付与・重複統合と信頼度付与・足切り境界（U11 / U15）

security-engineer と dependency-safety の指摘に対し、重要度の統一付与・重複統合（U11）と信頼度（0〜100）の付与（U15）を適用する分岐を検証する。統合時の低信頼足切り（C24）はオーケストレーター責務であることの境界も確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> mode=standard`（依存定義ファイル差分 + 脆弱性スキャン権限あり） |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 前提 | security-engineer と dependency-safety が同一箇所（例: 脆弱な依存を使う認証処理）を重複指摘し、かつ差分外の呼び出し元挙動を仮定した推測指摘も混在する |

## 分岐の根拠

references/skill-rules-matrix.md U11（重要度付与・重複統合）/ U15（信頼度付与）、`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U11 / U15、`${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` セクション 0〜3（評価語マッピング・重複統合）およびセクション 7（信頼度の定義・付与ルール 7.2・足切り 7.3）、references/checklist.md セクション A U11 / U15。

## 期待動作

- 各指摘に重要度（Critical / High / Medium / Low）を統一表記で付与する（U11 / severity-ranking.md セクション 0〜1）
- security-engineer と dependency-safety が同一ファイル・同一行（±5 行）・同一テーマを指摘した場合は 1 件に統合し、最も重い重要度を採用・担当を連名（「security-engineer + dependency-safety」）で記載する（severity-ranking.md セクション 3.1〜3.2）
- 各指摘に信頼度 0〜100 を付与する（U15）。脆弱性スキャン（EXECUTED）で実証された CVE 指摘は 90 以上、差分外の呼び出し元挙動・データ量を仮定した推測指摘は 60 未満とする（severity-ranking.md セクション 7.2）
- 統合した重複 2 件の信頼度は最も高い値を採用する（severity-ranking.md セクション 6 注記）
- 信頼度 60 未満の足切り（C24）は**オーケストレーターの責務**であり、本観点別スキルは中間レポートで各指摘に信頼度を併記して返すのみ（本スキルでは足切り・除外はしない）。境界は severity-ranking.md セクション 7.3（付与 = エージェント側 7.2 / 足切り = オーケストレーター側 C24）
- Critical 相当かつ信頼度 60 未満の指摘は握りつぶさず、要人間確認として残す方針を中間レポートに反映する（severity-ranking.md セクション 7.3 例外）

## 関連ケース

- case-01: 委譲・脆弱性スキャン EXECUTED（信頼度 90 以上が付与される CVE 指摘の供給元）
- code-review/case-07: オーケストレーター側の信頼度足切り（C24・足切りの実施側）
