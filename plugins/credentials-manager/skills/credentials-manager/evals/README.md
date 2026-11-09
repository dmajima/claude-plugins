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
| case-29 | Bash + 認証情報と無関係な環境変数の export → no-op | PreToolUse | 環境変数パターンの過検出抑制境界 |
| case-30 | Bash + 認証情報らしい環境変数の export → trigger | PreToolUse | 変数名の認証情報キーワード検出 → reader 起動指示 |
| case-31 | Read README.md → no-op | PreToolUse | Read 側の過検出抑制境界 |
| case-32 | PowerShell + Invoke-RestMethod → trigger | PreToolUse | matcher と分岐の PowerShell 対応 → reader 起動指示 |
| case-33 | PowerShell + 行頭の irm / 小文字表記 → trigger | PreToolUse | 大文字小文字を区別しない照合・別名の位置 |
| case-34 | PowerShell + curl.exe / パス付きの gh.exe → trigger | PreToolUse | CLI 名の拡張子・パス・引用符 |
| case-35 | PowerShell + `$env:GITHUB_TOKEN = ...` → trigger | PreToolUse | PowerShell / Windows の環境変数設定の検出 |
| case-36 | PowerShell + コマンド中の秘密情報パターン → trigger | PreToolUse | シークレット / Bearer パターンの PowerShell 適用 |
| case-37 | PowerShell + 必須プリフィクス付きのローカルコマンド → no-op | PreToolUse | PowerShell 側の過検出抑制境界 |
| case-38 | PowerShell + 認証情報と無関係な環境変数の設定 → no-op | PreToolUse | 環境変数パターンの過検出抑制境界（case-29 の PowerShell 版） |
| case-39 | Bash + `pwsh -c "$env:GITHUB_TOKEN = ..."` → trigger | PreToolUse | Bash から PowerShell を起動する経路 |
| case-40 | PowerShell + 認証情報らしい環境変数の参照 → no-op | PreToolUse | 環境変数の設定と参照の境界 |
| case-41 | PowerShell + CLI 名を含むパス → no-op | PreToolUse | パス付きの起動の検出に対する過検出抑制境界 |
| case-42 | 不正な入力 → no-op | PreToolUse | エラー系・fail-open |
| case-43 | プロンプト中の PEM 形式の秘密鍵 → trigger | UserPromptSubmit | PEM_PATTERN マッチ → reader 起動指示 |
| case-44 | 語の途中の sk- / メタデータだけに含まれる語 → no-op | PreToolUse | トークン形式の左側の境界・照合対象を tool_input に限定 |
| case-45 | Write のコンテンツ・シェルのコマンドに PEM / Basic → trigger | PreToolUse | UserPromptSubmit と共通のパターン |
| case-46 | シェルで認証情報系ファイルを操作 → trigger | PreToolUse | コマンドのトークンをファイル系ツールと同じ規則で判定 |
| case-47 | シェルのコマンドに認証情報系ファイルに似た語 → no-op | PreToolUse | 語幹の無い拡張子・除外リスト・語の一部の一致の境界 |
| case-48 | Grep / Glob で認証情報系ファイルを検索 → trigger | PreToolUse | matcher と分岐の Grep / Glob 対応・パスとファイル名のパターンの判定 |
| case-49 | Grep / Glob で通常のファイルを検索 → no-op | PreToolUse | 語の一部の一致・Grep の pattern（正規表現）の境界 |
| case-50 | jq が無い → ルールを配置し、検出フックが動作しないことを平文で通知 | SessionStart | 自己診断・jq が無いときの平文の出力 |
| case-51 | jq はあるが前提を欠く（lib なし・bash 4 未満）→ 配置の通知に添えて通知 | SessionStart | 自己診断・問題ごとの対処の案内 |
| case-52 | ルールを配置できない → 配置できなかったことを通知 | SessionStart | 配置の失敗（mkdir / cp）・fail-open |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

PreToolUse（case-18〜23・29〜42・44〜49）・UserPromptSubmit（case-17・24・43）・SessionStart（case-14〜16・25・50〜52）のケースの入力は、回帰テストで自動検証できる（副作用なし。`bash` と `jq` が必要。約 2〜3 分）。
秘密情報らしい値は、回帰テストの実行時に組み立てたダミーに置き換えている。

```bash
bash references/scripts/hooks/tests/test_hooks.sh   # プラグインのルートで実行（Windows では Git Bash）
```

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
