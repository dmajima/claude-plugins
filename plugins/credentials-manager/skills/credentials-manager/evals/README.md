# Evals: credentials-manager

このディレクトリは `credentials-manager` の動作分岐の期待挙動を例示する。

## ケース一覧

### スキル本体（v1.0.0）

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | URL 関連付き API キー保存（対話モード） | save 系 + URL あり |
| case-02 | 保存済み認証情報の一覧表示 | list 系 |
| case-03 | プロアクティブ検出（GitHub トークン） | 暗黙トリガー（パターン検出） |
| case-04 | URL アクセス時の自動マッチ（1 件ヒット） | 暗黙トリガー（URL 自動マッチ・単一） |
| case-05 | URL アクセス時の自動マッチ（複数件ヒット） | 暗黙トリガー（URL 自動マッチ・複数） |
| case-06 | URL アクセス時の自動マッチ（0 件） | 暗黙トリガー（URL 自動マッチ・該当なし） |
| case-07 | 削除（対話モードで確認あり） | delete 系 + 対話 |
| case-08 | 非対話モードでの保存 | 実行モード判定（非対話） |
| case-09 | 取得（retrieve、対象あり） | retrieve 系 + 部分一致単一ヒット |
| case-10 | 取得（retrieve、対象なし） | retrieve 系 + 一致なし → 保存提案 |
| case-11 | 既存 credentials.json の JSON パース失敗 | エラー系（バックアップ + 再初期化） |
| case-12 | user-scoped 保存（リポジトリ外） | パス解決・優先順位 2（フォールバック） |
| case-13 | `.gitignore` 未登録時の警告 | パス解決・優先順位 1 + `.gitignore` 未登録 |

### Hooks（v1.1.0）

| ケース | 内容 | hook | 主な分岐根拠 |
|-------|-----|------|-------------|
| case-14 | user スコープでテンプレート初回配置 | SessionStart | スコープ判定 user |
| case-15 | project スコープでテンプレート初回配置 | SessionStart | スコープ判定 project |
| case-16 | 既存ファイル時の no-op (idempotent) | SessionStart | ターゲット既存検出 |
| case-17 | プロンプト中の sk-* / ghp_* / AKIA 等検出 | UserPromptSubmit | SECRET_PATTERN マッチ |
| case-18 | WebFetch 呼び出し → trigger | PreToolUse | ツール種別 WebFetch |
| case-19 | Bash + curl → trigger | PreToolUse | 外部通信コマンド検出 |
| case-20 | Bash + ローカルコマンド → no-op | PreToolUse | 過検出抑制境界 |
| case-21 | Read .env → trigger | PreToolUse | 認証情報系ファイル該当 |
| case-22 | Read .env.example → no-op | PreToolUse | 除外リスト境界 |
| case-23 | Write コンテンツにシークレット → trigger | PreToolUse | コンテンツ内 SECRET_PATTERN |
| case-24 | プロンプト中の Bearer トークン検出 | UserPromptSubmit | BEARER_PATTERN マッチ |
| case-25 | 環境変数欠如時の silent exit | SessionStart | エラー系・fail-open |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

## 重要な検証観点

| 観点 | 確認内容 |
|-----|--------|
| グローバルルール非依存 | `~/.claude/rules/security/credentials-management.md` 不在環境でも case-04 / case-05 / case-06 の暗黙トリガーが発火すること |
| マスキング | フル値が会話出力に出ない |
| パス解決 | リポジトリ内 → `<repo>/.claude/.local/plugins/credentials-manager/credentials.json`、外 → `~/.claude/.local/plugins/credentials-manager/credentials.json` |
| `.gitignore` 確認 | リポジトリ内保存時、未登録なら警告が出る |
