# workspace-maintenance

Claude Code 環境のメンテナンス系プラグイン。古い作業フォルダ・セッションフォルダの安全なクリーンアップと、Git リポジトリを経由したグローバル設定（`settings.json` / `skills/` / `rules/` など）の同期機能を提供する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がプラグイン動作中に参照することはありません。
スキル本体は `skills/{skill-name}/SKILL.md` を、実作業手順は同 `references/` 配下を参照してください。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `cleanup-workspace` | スキル | グローバル（`~/.claude/.local/work/`）と各プロジェクト（`{repo}/.claude/.local/work/`）配下の古いセッションフォルダ・一時ファイルを安全にクリーンアップ。ドライラン + AskUserQuestion による削除前確認を必須化 |
| `sync-settings` | スキル | 特定の Git リポジトリから `settings.json` / `skills/` / `rules/` 等を `~/.claude/` へ pull 同期。ドライラン + 同期前バックアップを必須化 |

## 導入手順

### 前提

- Claude Code がインストール済み
- 動作要件のツールが PATH に通っていること（後述「動作要件」参照）
- 依存プラグインなし（`plugin.json` で `dependencies: []` を明示）

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install workspace-maintenance@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. 必要に応じてブランチ・タグ切替
cd <local-path>
git checkout <tag-or-branch>   # 例: git checkout v0.1.0 / git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install workspace-maintenance@dmajima-claude-plugins
```

### C. 自動更新の有効化（推奨）

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": {
        "type": "github",
        "repo": "dmajima/claude-plugins"
      },
      "autoUpdate": true
    }
  }
}
```

`autoUpdate: false` の場合は `/plugin update workspace-maintenance@dmajima-claude-plugins` を手動実行することで最新化できます。

### D. 依存関係

依存プラグインなし（`dependencies: []` を `plugin.json` で明示）。個別インストール手順の追加は不要です。

**外部ツール依存**:

- Git CLI（`sync-settings` スキルでリポジトリ clone / pull に使用）
- PowerShell 7+（Windows 環境での実行に推奨）

### 動作確認

```text
cleanup-workspace の dry-run を実行して
```

または

```text
sync-settings の dry-run を実行して
```

## 使い方

### 自然言語トリガー

| 発話例 | 起動スキル |
|-------|----------|
| 「古い作業フォルダを整理して」 | `cleanup-workspace` |
| 「セッションフォルダのクリーンアップ」 | `cleanup-workspace` |
| 「Claude の設定を Git から同期して」 | `sync-settings` |
| 「`~/.claude/` を Git リポジトリから更新」 | `sync-settings` |

### 安全装置

両スキルとも以下の安全装置を備えています:

| 安全装置 | cleanup-workspace | sync-settings |
|---------|-------------------|---------------|
| ドライラン（変更なしプレビュー） | 必須 | 必須 |
| `AskUserQuestion` による最終確認 | 必須 | 必須 |
| 削除/上書き前バックアップ | 任意 | 必須 |
| 操作対象パスのバリデーション | 必須 | 必須 |

## 動作要件

| ツール | 用途 |
|------|------|
| Git CLI 2.30+ | `sync-settings` スキルのリポジトリ clone / pull |
| PowerShell 7+（pwsh） | Windows 環境でのスクリプト実行 |
| Claude Code Read / Glob / Bash / AskUserQuestion ツール | 両スキル共通 |

## ファイル構成

```text
workspace-maintenance/
├── .claude-plugin/
│   └── plugin.json                     # プラグイン定義（version / category / keywords 等）
├── README.md                           # このファイル（人間向けリファレンス）
├── LICENSE                             # MIT ライセンス本文
└── skills/
    ├── cleanup-workspace/              # 古い作業フォルダ・セッションフォルダのクリーンアップ
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── references/
    │   └── evals/
    └── sync-settings/                  # Git リポジトリから設定を同期
        ├── SKILL.md
        ├── README.md
        ├── references/
        └── evals/
```

## 関連プラグイン

| プラグイン | 関係 |
|----------|-----|
| `plugins-update` | プラグイン / マーケットプレイスの一括更新（本プラグインと相補的） |
| `extension-toolkit` | プラグイン作成・公開ワークフロー |

## 関連ルール

- セッション作業領域: `~/.claude/rules/claude/work-directory.md`（`.claude/.local/work/` の運用）
- ローカルデータ領域: `~/.claude/rules/claude/local-data-directory.md`（`.claude/.local/` 全般）

## ライセンス

[MIT License](LICENSE) の下で配布されています。
