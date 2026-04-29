---
name: hook-toolkit
description: Claude Code のフック設定（hooks/hooks.json または settings.json の hooks セクション）を新規作成・改修するスキル。「PreToolUse フックを作って」「Stop イベントで通知音」「Bash 実行前にログを残す」「フックを settings.json から切り出してプラグイン化」などの依頼で起動する。Use when the user wants to create or modify a hook configuration. SKIP when the user wants to create a skill, plugin shell, command, or agent (use the corresponding creator skill).
---

# Hook Creator

Claude Code のフック設定（`hooks.json`）を作成・改修するスキル。プラグイン横断テンプレート（`templates/hook/hooks.json`）に従って構造化された生成物を出力する。

## 責務

- フック設定ファイル（`hooks.json`）の新規作成
- 既存フック設定への追加・更新
- イベント・matcher・command の設計支援
- フック内コマンドのパスポータビリティ確保

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| `settings.json` からフック抽出 → プラグイン化 | `plugin-toolkit`（移管シナリオ） |
| スキル/コマンド/エージェント生成 | 各 `*-creator` |
| マーケットプレイス公開 | `marketplace-publisher` |

## トリガー条件

- 「`{event}` フックを作って」（例: `PreToolUse`、`Stop`、`SessionStart`）
- 「`{tool}` 実行前 / 後に {動作} を追加したい」
- 「{動作} の通知フックを作る」

このスキルを起動しないケース:

- 「`settings.json` のフックをプラグイン化したい」（→ `plugin-toolkit` の移管シナリオ）

## 前提

- 配置先（`<repo>/.claude/settings.json` の `hooks` / `~/.claude/settings.json` の `hooks` / `plugins/{plugin}/hooks/hooks.json`）
- イベント名
- matcher（必要な場合）
- 実行コマンド

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり、または引数で全パラメータ指定 | 非対話 | デフォルト値・引数値で確定し進行 |
| 上記以外 | 対話 | 不足パラメータをユーザに確認 |

## 実行フロー

### 1. 配置先決定

| 配置先 | パス | 用途 |
|-------|-----|------|
| プロジェクト固有 | `<repo>/.claude/settings.json` の `hooks` | リポジトリでのみ有効 |
| グローバル | `~/.claude/settings.json` の `hooks` | 全プロジェクトで有効 |
| プラグイン同梱 | `plugins/{plugin}/hooks/hooks.json` | プラグイン配布 |

### 2. イベント選択

詳細は [references/hook-events.md](references/hook-events.md) を参照。

| カテゴリ | イベント | 用途例 |
|---------|---------|-------|
| ツール実行 | `PreToolUse` `PostToolUse` | コマンドログ・検証 |
| プロンプト | `UserPromptSubmit` | ユーザ入力前処理 |
| セッション | `SessionStart` `SessionEnd` | 初期化・後処理 |
| 応答 | `Stop` | 完了通知 |
| サブエージェント | `SubagentStop` | サブ完了処理 |
| 通知 | `Notification` | 通知時処理 |
| 圧縮 | `PreCompact` | 圧縮前処理 |

### 3. matcher 設計

| イベント | matcher の意味 |
|---------|--------------|
| `PreToolUse` / `PostToolUse` | ツール名の正規表現（例: `Bash`、`Edit\|Write`） |
| その他 | 通常不要、必要なら該当文字列の正規表現 |

### 4. command 設計

| 観点 | 内容 |
|-----|------|
| パスポータビリティ | プラグイン同梱なら `${CLAUDE_PLUGIN_ROOT}` を使う、ローカル絶対パス禁止 |
| timeout | 秒単位、デフォルト 60、軽い処理は短く（5〜10） |
| 終了コード | `0` = 成功、`2` = ブロック、その他 = 失敗 |
| 実行環境 | Bash / PowerShell / Node 等を選択（Windows 両対応推奨） |

詳細は [references/hook-events.md](references/hook-events.md) の「command 設計」を参照。

### 5. テンプレート展開

`${CLAUDE_PLUGIN_ROOT}/templates/hook/hooks.json` をベースに、選択したイベント・matcher・command を反映。

settings.json への追加の場合は既存 `hooks` を Read してマージ書き戻し（既存エントリを破壊しないこと）。

### 6. 既存ファイル更新時のエンコーディング維持

`settings.json` を編集する場合、元ファイルのエンコーディング・改行コードを維持する（`~/.claude/rules/common/file-encoding.md`）。

### 7. 検証

- [ ] JSON valid
- [ ] イベント名が正規（`PreToolUse` 等の正確な綴り）
- [ ] matcher の正規表現が valid
- [ ] command にローカル絶対パスのハードコードなし
- [ ] timeout が指定されている（デフォルト 60 秒）

### 8. 動作確認手順の提示

ユーザに動作確認手順を提示:

```text
動作確認:
1. Claude Code を再起動（フック設定の反映）
2. {対象操作} を実行
3. {期待される動作} を確認
```

### 9. 引き渡し

- 生成・変更したファイルパス提示
- プラグイン同梱なら `marketplace-publisher` への接続を提案

## 重要な制約

- `settings.json` の既存エントリを **絶対に破壊しない**（マージ書き戻し）
- ローカル絶対パスのハードコード禁止
- timeout を必ず指定する（デフォルト 60 秒、軽い処理は短く）
- パスポータビリティチェック必須
- エンコーディング維持必須
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md)）
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| ポータブルパス | [`../../references/path-portability.md`](../../references/path-portability.md) |
| 検証ルール | [`../../references/validation-rules.md`](../../references/validation-rules.md)（節 1 + 2.6） |
| イベント詳細 | [`references/hook-events.md`](references/hook-events.md) |
