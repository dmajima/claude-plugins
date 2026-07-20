# case-06 書き込み境界の遵守（プロダクションコード不変・認証情報のハードコード回避・.gitignore 追記提案）

フィクスチャ生成 / 拡充が **SUT のテストディレクトリのみ**に限定され、プロダクションコード・deep-test の他管理データを変更しないこと、および認証情報の実値をハードコードせず環境変数・credentials-manager 経由で扱うことを主軸に検証する。全ケース共通の不変条件を独立ケースとして固定する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web project=./ base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6） |
| 前提 | `analysis.yaml` 存在（web-app・認証 EP〔session。ログインにユーザー名 / パスワード必要〕・外部依存に決済 API）/ SUT にはプロダクションコード（アプリ本体・DB スキーマ）とテストディレクトリが併存 |

## 分岐の根拠

SKILL.md「重要な制約」（書き込み境界＝SUT テストディレクトリのみ・プロダクションコード / test-results / cases / analysis 不可・認証情報のハードコード禁止・storageState は .gitignore 追記提案）・「検証」チェックリスト、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 6.1 章（書き込み境界の表）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 4 章（書き込み境界・認証情報の SSOT）、`${CLAUDE_SKILL_DIR}/references/fixture-patterns.md` 1.1 章（認証情報は環境変数から取得）・5 章（.gitignore 追記提案）、credentials-management ルール（MANDATORY・認証情報の実値をハードコードしない）。

## 期待動作

- 生成 / 拡充する SUT テストコード（`playwright.config.ts` / `{tests}/fixtures/*.ts` / `auth.setup.ts` / seed）は **SUT のテストディレクトリ配下のみ** に Write/Edit する
- SUT の**プロダクションコード**（アプリ本体のソース・DB スキーマ・業務ロジック）を**一切変更しない**（テスト対象を「テストしやすく」するためのプロダクション改変もしない）
- `test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない（各所有スキルの専有）
- 認証情報の実値（ユーザー名 / パスワード / トークン / API キー）を config / fixture / setup に**ハードコードしない**。`process.env.*` 等の環境変数・credentials-manager 経由の取得コードとして記述する
- storageState 出力先（`tests/.auth/*.json`）はセッショントークンを含むため、`tests/.auth/` の `.gitignore` 追記を**提案**する（実トークンをコミットしない・対話確認 or 提案に留める）
- `deep-test:fixture-architect` を単独起動し、**書き込み境界の遵守**・**認証情報のハードコード有無**・.gitignore 追記提案の有無を重点評価させ、重大指摘（境界逸脱・ハードコード検出）があれば反映してから返却する
- 会話出力・fixtures.yaml・コミット対象に認証情報のフル値を出さない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | SUT テストディレクトリ配下のテストコードと `{base}/{target-slug}/fixtures.yaml` のみ。プロダクションコード・test-results.yaml / test-cases.yaml / analysis.yaml への変更なし。認証情報は環境変数参照コードでハードコードなし |
| 標準出力（要約） | フィクスチャ構築結果サマリ（生成先が SUT テストディレクトリに限定される旨・認証情報を環境変数化した旨・.gitignore 追記提案・fixture-architect の境界 / ハードコード所見） |
| 終了状態 | 書き込み境界と認証情報の安全性を遵守して返却。fixture-architect が境界逸脱 / ハードコードを検出した場合は反映後に返却 |

## 関連ケース

- case-01: 新規生成（本ケースの境界 / ハードコード条件も同時に満たす）
- case-02: 拡充（既存プロダクションコード不変・非破壊も本ケースの境界と連続）
- case-05: analysis.yaml を生成しない（逆生成しない書き込み境界の別面）
