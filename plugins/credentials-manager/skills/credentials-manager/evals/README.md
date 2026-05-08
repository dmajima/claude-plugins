# Evals: credentials-manager

このディレクトリは `credentials-manager` スキル（書き込み系）および同梱フックの動作分岐の期待挙動を例示する。参照系の評価ケースは `../../credentials-reader/evals/` を参照すること。

## ケース一覧

### スキル本体（書き込み系: save / update / delete / repair）

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | URL 関連付き API キー保存（対話モード） | save 系 + URL あり |
| case-07 | 削除（対話モードで確認あり） | delete 系 + 対話 |
| case-08 | 非対話モードでの保存 | 実行モード判定（非対話） |
| case-11 | 既存 credentials.json 破損時の修復（reader 引き継ぎ） | repair 系 + 引き継ぎ受け入れ |
| case-12 | user-scoped 保存（リポジトリ外） | パス解決・優先順位 2（フォールバック） |
| case-13 | `.gitignore` 未登録時の警告 | パス解決・優先順位 1 + `.gitignore` 未登録 |
| case-26 | 編集（update、対話モードで差分確認） | update 系 + 対話 |
| case-27 | `/credentials-manager:manage` コマンド経由の管理 | コマンド経由メニューUI + reader/manager 委譲 |
| case-28 | reader 引き継ぎ受け入れ（save、フル値非伝達） | reader → manager 引き継ぎ |

### Hooks（プラグイン同梱）

| ケース | 内容 | hook | 主な分岐根拠 |
|-------|-----|------|-------------|
| case-14 | user スコープでテンプレート初回配置 | SessionStart | スコープ判定 user |
| case-15 | project スコープでテンプレート初回配置 | SessionStart | スコープ判定 project |
| case-16 | 既存ファイル時の no-op (idempotent) | SessionStart | ターゲット既存検出 |
| case-17 | プロンプト中の sk-* / ghp_* / AKIA 等検出 | UserPromptSubmit | SECRET_PATTERN マッチ → reader 起動指示 |
| case-18 | WebFetch 呼び出し → trigger | PreToolUse | ツール種別 WebFetch → reader 起動指示 |
| case-19 | Bash + curl → trigger | PreToolUse | 外部通信コマンド検出 → reader 起動指示 |
| case-20 | Bash + ローカルコマンド → no-op | PreToolUse | 過検出抑制境界 |
| case-21 | Read .env → trigger | PreToolUse | 認証情報系ファイル該当 → reader 起動指示 |
| case-22 | Read .env.example → no-op | PreToolUse | 除外リスト境界 |
| case-23 | Write コンテンツにシークレット → trigger | PreToolUse | コンテンツ内 SECRET_PATTERN → reader 起動指示 |
| case-24 | プロンプト中の Bearer トークン検出 | UserPromptSubmit | BEARER_PATTERN マッチ → reader 起動指示 |
| case-25 | 環境変数欠如時の silent exit | SessionStart | エラー系・fail-open |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

## 重要な検証観点

| 観点 | 確認内容 |
|-----|--------|
| グローバルルール非依存 | `~/.claude/rules/security/credentials-management.md` 不在環境でもフック群が `credentials-reader` を起動指示すること |
| マスキング | フル値が会話出力に出ない |
| パス解決 | リポジトリ内 → `<repo>/.claude/.local/plugins/credentials-manager/credentials.json`、外 → `~/.claude/.local/plugins/credentials-manager/credentials.json` |
| `.gitignore` 確認 | リポジトリ内保存時、未登録なら警告が出る |
| 責務分離 | 参照系（list / retrieve / auto-match / proactive-detect）は credentials-reader、書き込み系（save / update / delete / repair）は credentials-manager |
| フック軽量化 | hook の `additionalContext` が credentials-reader 起動指示のみに絞られ、credentials-manager のスキル本体読み込みを誘発しないこと |
| 引き継ぎ | reader → manager 引き継ぎ時にフル値を残さず、ユーザに再入力させること |
