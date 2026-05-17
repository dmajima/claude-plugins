# maintenance

Claude Code 環境のメンテナンスを統合的に支援するプラグイン。プラグイン一括更新・古い作業フォルダのクリーンアップ・Git リポジトリ経由の設定同期を 1 つのプラグインに集約する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がプラグイン動作中に参照することはありません。
各機能の本体は `commands/{name}.md` / `skills/{name}/SKILL.md` および同 `references/` 配下を参照してください。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `/update-all` | コマンド | 全マーケットプレイスとインストール済みプラグインを公式 CLI 経由で一括更新 |
| `plugin-updater` | スキル | `/update-all` の実作業を担う（Phase A-0〜G、横断ルール XR-1〜5） |
| `cleanup-workspace` | スキル | `.claude/.local/work/` 配下の古いセッションフォルダ・一時ファイルを多層安全装置付きで削除 |
| `sync-settings` | スキル | 特定の Git リポジトリから `~/.claude/` 配下の設定（settings.json / skills / rules 等）を pull 同期 |

## 既存ユーザ向け移行手順（plugins-update v1.x からの移行）

**`plugins-update` プラグイン v1.x をご利用の方**: 本プラグインは旧 `plugins-update` の機能を `plugin-updater` スキルとして取り込んでいます。

```text
# 旧プラグインをアンインストール
/plugin uninstall plugins-update@dmajima-claude-plugins

# 新プラグインをインストール
/plugin install maintenance@dmajima-claude-plugins
```

`/update-all` コマンドはそのまま利用できます（互換性維持）。旧 `plugins-update@dmajima-claude-plugins` 名前空間でのインストールは今後できなくなります。

設計判断の経緯は `skills/plugin-updater/references/architecture-decisions.md` の ADR-PU-010 を参照してください。

## 導入手順

### 前提

- Claude Code がインストール済みで `claude plugin` サブコマンドが利用可能
- Git CLI 2.30+（`sync-settings` / `plugin-updater` で必要）
- PowerShell 7+（Windows 環境主軸）
- 依存プラグインなし（`plugin.json` で `dependencies: []` を明示）

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install maintenance@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. 必要に応じてブランチ・タグ切替
cd <local-path>
git checkout <tag-or-branch>   # 例: git checkout v0.2.0 / git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install maintenance@dmajima-claude-plugins
```

### C. 自動更新の有効化（推奨）

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時に自動更新されます。

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

`autoUpdate: false` の場合は `/plugin update maintenance@dmajima-claude-plugins` を手動実行することで最新化できます。

### D. 依存関係

依存プラグインなし（`dependencies: []` を `plugin.json` で明示）。

**外部ツール依存**:

- Git CLI 2.30+
- PowerShell 7+
- Claude Code CLI（`/update-all` で `claude plugin` サブコマンドを呼び出す）

### 動作確認

```text
/update-all --dry-run
```

または

```text
cleanup-workspace の dry-run を実行して
```

## 使い方

### スラッシュコマンド

| コマンド | 効果 |
|---------|-----|
| `/update-all` | 全マーケットプレイスとプラグインを最新化 |
| `/update-all --dry-run` | 実行予定の CLI コマンドのみ表示 |
| `/update-all --scope user\|project\|local` | 指定スコープのプラグインのみ更新 |

### 自然言語トリガー

| 発話例 | 起動 |
|-------|-----|
| 「古い作業フォルダを整理して」 | `cleanup-workspace` |
| 「セッションフォルダのクリーンアップ」 | `cleanup-workspace` |
| 「Claude の設定を Git から同期して」 | `sync-settings` |
| 「`~/.claude/` を Git リポジトリから更新」 | `sync-settings` |
| 「プラグインを最新にして」 | `plugin-updater`（`/update-all` 経由が推奨） |

### 安全装置

破壊的操作を行う 3 機能すべてに以下を採用しています:

| 装置 | plugin-updater | cleanup-workspace | sync-settings |
|---------|----------------|-------------------|---------------|
| ドライラン（変更なしプレビュー） | 必須 | 必須 | 必須 |
| 安全装置（バリデーション / 確認） | 必須（XR-1〜5）| 必須（パス・LinkType・進行中）| 必須（除外フィルタ・URL 検証）|
| ロールバック手段 | アンインストール + 旧版再インストール | （削除のため不可、事前バックアップ推奨） | バックアップディレクトリ |
| 認証情報の保護 | 出力サニタイズ（XR-3） | 適用外 | 自動除外 |

## ファイル構成

```text
maintenance/
├── .claude-plugin/
│   └── plugin.json                            # プラグイン定義（version / category / keywords 等）
├── README.md                                   # このファイル（人間向けリファレンス）
├── LICENSE                                     # MIT
├── commands/
│   └── update-all.md                           # /update-all コマンド本体
└── skills/
    ├── plugin-updater/                         # /update-all の実作業スキル（Phase A-0〜G）
    │   ├── SKILL.md
    │   ├── README.md
    │   └── references/
    │       ├── phase-flow.md
    │       ├── output-formats.md
    │       ├── cross-cutting-rules.md
    │       └── architecture-decisions.md       # ADR-PU-001〜010（ADR-PU-010 で maintenance 統合決定）
    ├── cleanup-workspace/                      # 古い作業フォルダのクリーンアップ
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── references/
    │   │   ├── procedures.md
    │   │   ├── safety.md
    │   │   └── scripts/cleanup/cleanup.ps1
    │   └── evals/                              # 12 ケース
    └── sync-settings/                          # Git リポジトリから設定を同期
        ├── SKILL.md
        ├── README.md
        ├── references/
        │   ├── procedures.md
        │   ├── safety.md
        │   ├── strategies.md
        │   └── scripts/sync/sync.ps1
        └── evals/                              # 12 ケース
```

## 関連プラグイン

| プラグイン | 関係 |
|----------|-----|
| `extension-toolkit` | プラグイン作成・公開ワークフロー |
| `credentials-manager` | 認証情報管理。`sync-settings` でプライベート repo 利用時に連携 |
| `session-usage` | セッショントークン消費の可視化（`category=diagnostics` として独立配布、本プラグインとは別関心） |

## 関連ルール

- セッション作業領域: `~/.claude/rules/claude/work-directory.md`（`.claude/.local/work/` の運用）
- ローカルデータ領域: `~/.claude/rules/claude/local-data-directory.md`（`.claude/.local/` 全般）
- 自動更新ポリシー: `~/.claude/rules/claude/plugin-auto-update.md`（`autoUpdate: true` 必須・週 1 回更新チェック）

## ライセンス

[MIT License](LICENSE) の下で配布されています。
