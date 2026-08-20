# case-01: 標準の初期構築（対話モード）

## 入力

```text
/project-harness:init
```

前提: 対象は git リポジトリ。コミットあり。`.claude/references/` 未構築。ルート CLAUDE.md なし。

## 期待動作

1. git リポジトリ確認・既存ハーネス検査（未構築を確認）が行われる
2. 既存資産（README・docs/ 等）の検出結果と取り込み方針が AskUserQuestion で確認される
3. 調査サブエージェント 4 系統（技術スタック・環境 / 機能・画面 / アーキテクチャ・データ / 規約・判断・用語）が並列起動される
4. 検出された機能一覧が提示され、生成範囲（全機能 / 主要機能のみ / 個別選択）が AskUserQuestion で確認される
5. `.claude/CLAUDE.md` + `references/` 一式が structure-spec.md 準拠で生成される
6. `environments/` の検証コマンドは実行確認済みのものだけが記載される
7. `.sync-state.json` が HEAD の SHA で初期化される

## 期待出力

- 生成ファイル一覧（フォルダ別件数）
- 解析サマリ（技術スタック・文書化した機能数 / 未文書化機能数）
- `TODO:` 残数と代表例
- 運用案内（`/project-harness:update`・鮮度通知・`threshold_commits` 調整）

## 禁止事項（このケースで起きてはならないこと）

- ソースから確認できない仕様の捏造（未確認は `TODO:` 明示）
- 対象プロジェクトの既存ファイルの無確認変更
- `.claude/CLAUDE.md` の 100 行超過

## 分岐の根拠

SKILL.md 実行フロー 1〜7 の正常系。Phase 1 の全検査が通過し、対話モードで確認を挟みながら生成する基本経路。

## 関連ケース

- [case-03](case-03_non_interactive.md): 同フローの非対話版
- [case-02](case-02_existing_harness.md) / [case-06](case-06_partial_harness.md) / [case-05](case-05_not_git_repo.md) / [case-07](case-07_no_commits.md): Phase 1 検査で分岐するケース群
- [case-08](case-08_bulk_generation_delegation.md): 生成対象が多くエージェント委譲となるケース
