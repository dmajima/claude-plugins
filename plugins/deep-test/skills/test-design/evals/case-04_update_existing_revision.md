# case-04 既存ケースの更新（revision 規則）

既存の test-cases.yaml に対する仕様変更反映のケース。内容変更ケースの revision +1 と draft 戻し、削除相当の deprecated 論理削除、追加ケースの続番採番、変更なしケースの承認状態維持を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「仕様変更でログイン後の遷移先がダッシュボードからホーム画面に変わった。TC-FUNC-001 を直して、TC-FUNC-003 の機能は廃止されたので消して、ホーム画面の表示確認を追加して」 |
| 起動形態 | 単独（ユーザー直接起動・対話） |
| 前提 | `{target-slug}/test-cases.yaml` に TC-FUNC-001（revision: 1 / approved）・TC-FUNC-002（revision: 1 / approved・今回変更なし）・TC-FUNC-003（revision: 2 / approved）が存在 |

## 分岐の根拠

SKILL.md「実行フロー」5（更新: revision 規則遵守）・「重要な制約」（ID 改変・物理削除・deprecated ID 再利用の禁止 / 内容変更のないケースの approved 維持）、references/design-procedures.md 7 章（更新手順の分類表・確定時 1 回のインクリメント）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` 2.2 章（ID 改変禁止・欠番許容・再利用禁止）・`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 3 章（revision +1 で draft 戻し・論理削除のみ）。

## 期待動作

- TC-FUNC-001: expected / steps を新遷移先に更新し、`revision: 2` へ +1、`review_status: draft` に戻し、`updated_at` を更新する（ID は変更しない）
- TC-FUNC-003: `deprecated: true` を設定する（cases[] から物理削除しない。revision・過去の内容は保持）
- 追加ケース: `TC-FUNC-004` として採番する（deprecated を含む既存最大連番 003 の続番。003 の ID を再利用しない）。`revision: 1` / `review_status: draft`
- TC-FUNC-002: 一切変更しない（`review_status: approved` と `updated_at` を維持する）
- `meta.updated_at` を更新する
- test-architect の自己チェックを実施してから返却する（更新でも省略しない）
- 返却のケースサマリ表に 新規 1 / 更新 1 / deprecated 1 を区別して報告し、「変更・追加ケースは draft のため test-review（設計文脈）の再承認が必要」と明記する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/test-cases.yaml` の更新（TC-FUNC-001 は `revision: 2`・draft 戻し / TC-FUNC-003 は `deprecated: true` の論理削除 / 追加は続番 `TC-FUNC-004`・`revision: 1`・draft / TC-FUNC-002 は approved のまま不変更・`meta.updated_at` 更新）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 新規 1 / 更新 1 / deprecated 1 を区別したケースサマリ表と「変更・追加ケースは draft のため test-review（設計文脈）の再承認が必要」の明記 |
| 終了状態 | test-architect の自己チェック後、変更・追加ケースが `review_status: draft` の状態で返却。設計レビューでの再承認待ち |

## 関連ケース

- case-01: 新規生成（revision: 1 の初期状態）
