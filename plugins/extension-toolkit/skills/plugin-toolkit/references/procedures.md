# 実行手順詳細

`plugin-toolkit` の詳細実行手順。

## シナリオ判定

| シナリオ | 入力の特徴 | 主な動作 |
|---------|----------|---------|
| 新規外形のみ | プラグイン名指定、移管対象指定なし | 外形のみ作成 |
| 新規外形 + 中身配置 | プラグイン名指定、移管対象指定あり | 外形作成 + 既存資産コピー |
| 既存プラグインへの追加 | プラグイン名 = 既存、追加対象指定 | 中身追加のみ |
| 既存資産のプラグイン化 | 移管対象指定、配置先プラグイン未指定 | 配置先確認 → シナリオ A or C へ分岐 |

## 外形生成手順（新規時）

### 1. パラメータ確定

| パラメータ | 必須 | 例 | 確認方法 |
|----------|------|---|---------|
| プラグイン名（kebab-case） | 必須 | `dev-toolkit` | 引数 or 対話 |
| 1 行説明 | 必須 | `開発支援ツールキット` | 引数 or 対話 |
| 作者名 | 任意 | `dmajima` | 引数 or プラグイン作者デフォルト |
| 含めるアイテム種別 | 必須 | `commands,skills,hooks` | 引数 or 対話 |
| キーワード | 任意 | `["dev","toolkit"]` | 引数 or 空配列 |

### 2. 配置先決定

| 配置先 | パス |
|-------|-----|
| 現在のリポジトリのマーケットプレイス | `<repo>/plugins/{plugin-name}/` |
| 単独配置（マーケットプレイス未確定） | カレントディレクトリ配下 |

### 3. テンプレート展開

`${CLAUDE_PLUGIN_ROOT}/references/templates/plugin/` を配置先にコピーし、プレースホルダ置換。

| プレースホルダ | 置換値 |
|--------------|-------|
| `{plugin-name}` | プラグイン名 |
| `{プラグインの 1 行説明}` | 1 行説明 |
| `{author-name}` | 作者名 |
| `{marketplace-name}` | マーケットプレイス名（既知の場合） |

### 4. サブディレクトリ作成

含めるアイテム種別に応じて以下を作成:

| 種別 | 作成パス |
|-----|---------|
| commands | `commands/` |
| skills | `skills/` |
| agents | `agents/` |
| hooks | `hooks/` |
| mcp | `mcp/` |

git は空ディレクトリを追跡しないため、`.gitkeep` を置くか、直後に実体ファイルを配置する。

## 移管手順

### 1. 移管元の特定

| 種別 | 検索パス |
|-----|---------|
| スキル | `<repo>/.claude/skills/{name}/SKILL.md`、`~/.claude/skills/{name}/SKILL.md` |
| コマンド | `<repo>/.claude/commands/{name}.md`、`~/.claude/commands/{name}.md` |
| エージェント | `<repo>/.claude/agents/{name}.md`、`~/.claude/agents/{name}.md` |
| フック | `<repo>/.claude/settings.json` または `~/.claude/settings.json` の `hooks` |

複数候補がある場合（プロジェクトとグローバル両方等）は対話で確認する。

### 2. 配置先決定

| 種別 | 配置先 |
|-----|-------|
| スキル | `plugins/{plugin}/skills/{name}/`（ディレクトリ全体） |
| コマンド | `plugins/{plugin}/commands/{name}.md` |
| エージェント | `plugins/{plugin}/agents/{name}.md` |
| フック | `plugins/{plugin}/hooks/hooks.json`（該当部分のみ抽出） |

### 3. コピー実行

| 種別 | 方法 |
|-----|------|
| スキル | ディレクトリ全体を再帰的にコピー（Bash `cp -r` または Read+Write） |
| コマンド・エージェント | 単体ファイルを Read + Write |
| フック | `settings.json` を Read、該当 hooks エントリのみ抽出して新規 `hooks.json` を Write |

詳細マッピングは [migration-rules.md](migration-rules.md) を参照。

### 4. 既存資産の保護

- 元ファイルを **絶対に変更しない**（コピーのみ）
- 元 `settings.json` のフックを削除しない（プラグイン化後に元を残すかはユーザ判断）

### 5. パスポータビリティチェック

移管後のファイルすべてに対し Grep でローカル絶対パスを検出。詳細は [`../../../references/policies/path-portability.md`](../../../references/policies/path-portability.md) を参照。

検出時の対応:

| 分類 | 対応 |
|-----|------|
| NG | 削除 or `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}` で置換 |
| 例外候補 | プラグイン README の「依存システム」セクションへ追記 |

### 6. 既存ファイル更新時のエンコーディング維持

移管対象ファイルが UTF-8 以外の場合、Edit/Write ツール直接使用は禁止。Python 経由で元エンコーディングのまま書き戻す。詳細は `~/.claude/rules/common/file-encoding.md` を参照。

## 既存追加シナリオ

既存プラグインへの中身追加。

### 1. プラグイン存在確認

`plugins/{plugin-name}/` の存在を確認。未存在なら新規外形作成シナリオへ切り替え。

### 2. 衝突確認

追加対象のスキル/コマンド/エージェント名がプラグイン内に既存していないか確認。既存ならユーザに上書き可否を確認（無確認上書き禁止）。

### 3. 移管実行

通常の移管手順を実施。

### 4. プラグインの README 更新案内

中身追加に伴い README の「提供機能」が変わるため、`readme-toolkit` への接続を提案。

## 失敗時のリカバリ

| 失敗 | リカバリ |
|-----|---------|
| プレースホルダ置換漏れ | `{` の Grep で残存検出、再置換 |
| パスポータビリティ NG | 該当箇所を変数 or 相対パスに置換 |
| 既存ファイル誤上書き | git の元状態に戻す（リカバリ前にユーザに必ず確認） |
| エンコーディング破壊 | バックアップから復元、Python 経由で再書き込み |
