# test-design evals

本ディレクトリは `test-design` フェーズスキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_full_new_design.md | 新規設計フル（レベル未指定 → 提案 → AskUserQuestion 確定 → 計画 + ケース生成 → test-architect 自己チェック） | 単独・対話 |
| 02 | case-02_spec_provided.md | `spec=` 指定あり（仕様書読解と requirement 対応付け） | 委譲 |
| 03 | case-03_levels_specified.md | `levels=` 指定あり（提案・確認を省略して指定採用。不整合時は警告） | 委譲 |
| 04 | case-04_update_existing_revision.md | 既存 test-cases.yaml の更新（revision +1・draft 戻し・deprecated 論理削除・ID 続番） | 単独・対話 |
| 05 | case-05_non_interactive.md | 非対話モード × 既存 slug 複数（自動選択せずエラー中断・明示指定を案内） | 委譲・非対話 |
| 06 | case-06_non_interactive_auto_adoption.md | 非対話モード × 既存 slug 1 件（slug とレベル提案を自動採用・採用根拠を明記して設計完遂） | 委譲・非対話 |
| 07 | case-07_target_unspecified.md | テスト対象（対象説明= / 位置引数）が完全未指定 × 対話（AskUserQuestion で確認。target-slug 解決の case-05/06 とは別軸） | 委譲・単独 |
| 08 | case-08_target_unspecified_non_interactive.md | テスト対象が完全未指定 × 非対話（AskUserQuestion 不可でエラー中断・明示指定を案内。case-07 の対） | 委譲・単独 |
| 09 | case-09_target_slug_existing_interactive.md | 対話 × 既存 target-slug 1 件以上 → AskUserQuestion で既存一覧+新規作成を提示し選択で分岐（非対話 case-05/06 の対話版。test-analyze case-14 の様式） | 単独・対話 |
| 10 | case-10_target_slug_zero_non_interactive.md | 非対話 × 既存 target-slug 0 件 → 対象名から kebab-case 自動生成（サブA）/ 特定不可はエラー中断（サブB・捏造回避。test-analyze case-13 の様式） | 委譲・非対話 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提状態 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き（呼ばれるエージェント・生成物・返却内容） |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（生成物と返却内容への参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 起動形態と対話モードの軸について

本スキルの evals は「委譲（オーケストレータ `test` 経由）/ 単独」と「対話 / 非対話」の 2 軸で分岐を検証する。
委譲時は target-slug 等が引数で確定済みのため確認が減り、単独時は本スキル自身が target-slug 解決（data-locations.md 4 章）を行う。
入力欠落の分岐は 2 種を区別する: **target-slug 解決**（どの既存テストデータ領域を使うか。非対話の複数 = case-05 / 1 件 = case-06 / 0 件 = case-10、対話の既存選択 = case-09、data-locations.md 4.2 章）と、**テスト対象の不在**（何をテスト対象とするか＝対象説明の不在。対話 = case-07 / 非対話 = case-08、design-procedures.md 2 章）。
どの分岐でも共通する不変条件: 生成・変更したケースは常に `review_status: draft`、test-architect の自己チェックを経てから返却、test-results.yaml へは書き込まない。
