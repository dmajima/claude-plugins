# case-01 新規設計フル（レベル提案 → 確定 → 生成 → 自己チェック）

初回のテスト設計をレベル未指定で依頼されたケース。対象分析 → レベル提案 → AskUserQuestion 確定 → test-plan.md / test-cases.yaml 生成 → test-architect 自己チェック → 返却の一連の流れを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「https://localhost:5001 の受注管理 Web アプリのテストを設計して。リポジトリはカレント」 |
| 起動形態 | 単独（ユーザー直接起動・対話） |
| 前提 | `{target-slug}/` は未作成（既存 slug なし） / 仕様書指定なし / リポジトリに画面・API 実装と外部決済 API 連携が存在 |

## 分岐の根拠

SKILL.md「実行フロー」1〜7 および「実行モード判定」（対話: レベル選定を AskUserQuestion で確定）、references/design-procedures.md 2 章（単独時の target-slug 解決）・3 章（対象分析）・4 章（提案の作成と確定）・5〜6 章（生成手順）・8 章（自己チェック）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4 章（新規 slug 作成）、`${CLAUDE_PLUGIN_ROOT}/references/agents.md`（test-architect 単独起動・共通注入事項）。

## 期待動作

- target-slug を data-locations.md 4 章のフローで解決する（既存なし → 対話で新規 slug 名を確認して作成）
- リポジトリを Read / Glob / Grep で分析し、機能・画面・API・外部 IF の一覧を整理する（勝手にブラウザアクセスによる探索をしない）
- 分析結果からレベル提案を作成し（外部決済連携があるため `integration-external` を含む）、AskUserQuestion（複数選択・各レベルに 1 行説明付き）で確定する
- `{target-slug}/test-plan.md` を 6 セクション（対象概要・テスト方針・レベル別スコープ・環境前提・データ方針・スケジュール目安）で生成する
- `{target-slug}/test-cases.yaml` を yaml-schema.md 準拠で生成する: 全ケース `revision: 1` / `review_status: draft`、ID は `TC-{LEVEL}-001` からの採番、境界値・異常系ケースを含む、`automation: playwright` のケースは具体的な画面操作 steps を持つ
- Agent ツールで `deep-test:test-architect` を単独起動する（プロンプトに agents.md 4.3 章の共通注入事項ブロックと解決済みパスを含める）
- test-architect の重大指摘を計画・ケースへ反映してから返却する（エージェントに成果物を修正させない）
- 返却に SKILL.md「引き渡し」のサマリ（レベル別ケース数表・所見・未確認事項・「test-review の承認が必要」）を含める
- test-results.yaml を作成・編集しない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/test-plan.md`（6 セクション）・`test-cases.yaml`（全ケース `revision: 1`・`review_status: draft`・`TC-{LEVEL}-001` からの採番、境界値・異常系を含む）。test-results.yaml へは書き込まない |
| 標準出力（要約） | レベル別ケース数表・所見・未確認事項・「test-review の承認が必要」を含む生成サマリと返却 |
| 終了状態 | test-architect の自己チェック（重大指摘反映）後、全ケース `review_status: draft` で返却。単独完結せず後続の設計レビューへ |

## 関連ケース

- case-02: 仕様書指定ありの分析（requirement 対応付け）
- case-03: レベル指定ありで AskUserQuestion を省略
- case-05: 非対話でのレベル自動採用
