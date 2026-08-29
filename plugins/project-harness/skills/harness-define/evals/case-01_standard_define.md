# case-01: 標準の仕様先行構築（対話モード）

## 入力

```text
/project-harness:define
```

前提: 新規プロジェクト。`git init` 済みでコミットは 0 件。`.claude/references/` 未構築。コード実態なし。提供資料なし（ヒアリングのみ）。

## 期待動作

1. Phase 1 の前提確認で git リポジトリであることを確認する。コミット 0 件は **中断せず**、Phase 6 で初回コミットにより同期基準を確立する旨を控える。既存ハーネス未構築・コード実態なしを確認し、骨格生成ありで続行する
2. Phase 2 で提供資料・既存ドキュメントの検出結果（該当なし）を提示し、ヒアリングのみで進める方針を確認する
3. Phase 3 で「目的・背景 → スコープと機能要求 → 画面・業務フロー → 業務ルール・用語 → 非機能・制約」の順にヒアリングする。ユーザが「決めていない・分からない」と答えた事項はその場で埋めず未確定事項（`TODO:`）として記録する
4. Phase 4 で structure-spec.md 節 10 の骨格生成順序に従い骨格を生成し（`requirements/` を含む）、テンプレートから葉のドキュメントを生成する。各ドキュメントには `status: draft`・`sources: []`・合意ベースの定型注記（authoring-spec.md 節 1.1）・出典（合意日）を設定する。`system-designs/` は原則生成せず、技術スタックが未決定なら `architecture/` / `decisions/` も生成しない（`requirements/` の制約欄に「未決定」と記す）。節 10 手順 7 の gitignore 検査（2 段階）と手順 8 のルート `CLAUDE.md` 到達性確保（本ケースは不在のため最小スタブ作成の承認確認）も実施する
5. Phase 5 で生成した `draft` 一覧と要旨を提示し、`AskUserQuestion` で合意可否を確認する。承認されたドキュメントを `status: agreed` に更新し `updated` を更新する
6. Phase 6 で `.claude/` 配下の初回コミットの実施可否を `AskUserQuestion` で確認し、承認後にパス限定ステージング（`git add -- .claude/` + 承認済みルート資産）でコミットする。その SHA で `.sync-state.json` を初期化する（`threshold_commits: 30`）
7. Phase 7 で検証スクリプトを実行し、`git status --porcelain` で `.claude/` 外への意図しない書き込みが無いことを確認する

## 期待出力

- 生成ファイル一覧（フォルダ別件数）
- 合意状態（`agreed` N 件 / `draft` M 件）
- 未確定事項一覧（`TODO:` の要旨）
- 検証スクリプトの結果
- 初回コミット・`.sync-state.json` 初期化の実施有無
- 運用案内（実装開始後は `/project-harness:update` の実装追随で `sources` 紐付けと `implemented` 昇格が提案される旨。仕様の追加・改訂は本スキルの再実行）

## 禁止事項（このケースで起きてはならないこと）

- ヒアリングで合意していない事項を「合意した」ものとして記載すること（エージェントの自己判断禁止。authoring-spec.md 節 1.1）
- `status: draft` / `agreed` ドキュメントでの合意ベース定型注記・出典の省略
- 実装が無いにもかかわらず `sources` へ推測のパスを記入すること（`sources: []` が正）
- 未確定事項（`TODO:`）の残存を品質欠陥として報告すること（spec-first では多いのが正常）
- ユーザ承認を経ない初回コミットの実行
- `.claude/CLAUDE.md` の 100 行超過

## 分岐の根拠

SKILL.md 実行フロー 1〜7 の正常系。procedures.md Phase 1 の全検査（git リポジトリあり / コミット 0 件は中断しない / 既存ハーネスなし / コード実態なし）を通過し、対話モードで骨格生成から合意確認・初回コミット・検証まで一巡する基本経路。

## 関連ケース

- [case-02](case-02_with_materials.md): 提供資料がある場合の取り込み
- [case-03](case-03_existing_harness.md): 既存ハーネスありでドキュメント追加のみとなる場合
- [case-04](case-04_non_interactive.md): 同フローの非対話版
- [case-06](case-06_no_commits_first_commit.md): コミット有無検査と初回コミット承認ゲートの分岐詳細
- [case-08](case-08_bulk_generation_delegation.md): 生成対象が多くエージェント委譲となるケース
- [case-11](case-11_partial_harness.md): 部分的に構築済みのハーネスへの骨格補完
- [case-12](case-12_gitignore_check.md): gitignore 検査でハーネス本体の無視を検出する分岐詳細
- [case-13](case-13_root_claude_md.md): ルート CLAUDE.md 到達性確保の分岐詳細（既存時 / 不在時 / 拒否時）
