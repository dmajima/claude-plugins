# Evals: harness-update

このディレクトリは `harness-update` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | 標準の差分反映（対話モード） | SKILL.md 実行フロー 1〜7 |
| case-02 | 乖離ゼロ（同期済み） | Phase 1 乖離有無検査 |
| case-03 | ハーネス未構築プロジェクトでの起動 | Phase 1 ハーネス存在検査 |
| case-04 | 非対話モード | 実行モード判定 |
| case-05 | 対応ソースの削除検出（整理候補 3 択） | Phase 2 整理候補分類 + structure-spec 節 6.1 |
| case-06 | .sync-state.json の破損（非対話時は中断） | Phase 1 state 妥当性検査 |
| case-07 | rebase 等で last_synced_commit が到達不能（非対話時は中断） | Phase 1 SHA 到達可能性検査 |
| case-08 | 変更が .claude/ 配下のみ（ハーネス直接編集） | sync-spec 節 2 の分類 |
| case-09 | 反映対象 5 件超過時のサブエージェント委譲 | Phase 4 委譲条件 + agents.md |
| case-10 | git リポジトリでないプロジェクトでの起動 | Phase 1 git リポジトリ検査 |
| case-11 | 委譲エージェントの違反を統合検証で検出 | agents.md 境界検証・違反時の是正 |
| case-12 | リファクタリングのみの差分（反映範囲の絞り込み） | Phase 2 コミットメッセージの活用 |
| case-13 | ソースの移動（rename）を検出 | sync-spec 節 2「ソース移動」分類 |
| case-14 | 全量監査モード（--full） | sync-spec 節 4 |
| case-15 | 構成仕様バージョンの差異を検出 | sync-spec 節 5 |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。
本スキルは対象プロジェクトの git 履歴・ハーネス状態に依存する AI 主導スキルのため、自動実行スクリプト（demo.sh）は適用外とし、目視確認を基本とする。
反映後の機械検証は `${CLAUDE_PLUGIN_ROOT}/references/scripts/validate/validate_harness.sh` が担う。

## ケース追加ルール

新しい分岐ロジックを追加した時は、対応するケースファイル（`case-{2 桁番号}_{snake_case 名}.md`）を必ず追加し、本一覧表を同期する。各ケースには「分岐の根拠」「関連ケース」セクションを含める。
