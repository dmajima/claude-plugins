# design-bridge

Markdown の画面設計書とローカルのモック HTML を正本（SSOT）として、claude.ai/design の design-system プロジェクトへ同期するプラグインです。設計フェーズと実装フェーズを通じて、設計書・モック・Claude Design 上のカードが食い違わないことを、運用ルールではなく Claude Code のフック機構で担保します。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 導入手順

### 前提

| 要件 | 必須 | 用途 |
|------|------|------|
| Claude Code | 必須 | — |
| claude.ai の design-system 認可（`/design-login`） | 必須 | `DesignSync` ツールの利用 |
| Python 3.9 以上 | 必須 | モックのスクリーンショット生成（`bridge-init` が venv を構築） |
| git リポジトリ | 必須 | プロジェクトルートの判定に `.git` を使う |
| `jq` | 任意 | 既定以外の監視対象を設定する場合。無い場合は既定（`specs` の `.md`、`mocks` の `.html`）に縮退します |

プラグイン依存はありません（`plugin.json` の `dependencies` は空）。

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add dmajima/claude-plugins
/plugin install design-bridge@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

```bash
git clone https://github.com/dmajima/claude-plugins <local-path>
cd <local-path>
git checkout main
```

```text
/plugin marketplace add <local-path>
/plugin install design-bridge@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時に自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": { "type": "github", "repo": "dmajima/claude-plugins" },
      "autoUpdate": true
    }
  }
}
```

### D. セットアップと動作確認

インストール後、Claude Code を再起動してからプロジェクトで初期化します。

```text
/design-init
/design-status
```

`bridge-init` が Playwright の Chromium を取得するため、初回にダウンロードが発生します（展開後 約 690 MB）。

## 解決する課題

Markdown の画面設計書だけでは画面イメージが伝わらず、かといって Claude Design 上にモックを作っても、設計書・モック・実装のどれかを直した瞬間に三者が乖離します。`DesignSync` ツールにはリモート変更の通知機構（watch）がないため、放置すると「承認したカード」と「正本の設計書」がずれ、承認プロセスそのものが壊れます。

本プラグインは次の方針でこれを防ぎます。

| 方針 | 内容 |
|------|------|
| 正本はローカル | `specs/` の Markdown と `mocks/` の HTML だけが正本。Claude Design は表示・承認用の鏡 |
| push は自動強制 | 設計書・モックを変更した応答は、反映が終わるまで Stop フックで終了できない |
| 種別で誘導先を変える | モックの未反映は `bridge-push`、設計書の未反映は `bridge-mock`（モック再生成）へ案内する |
| pull は明示のみ | Claude Design 側を正とする取り込みは、ユーザーが明示的に指示したときだけ実行する |
| 画面イメージは実体化 | モックのスクリーンショットをリポジトリに置き、Markdown から相対参照する |

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `bridge-init` | スキル | 導入。ディレクトリ構成の作成、Claude Design プロジェクトの紐付け、venv 構築 |
| `bridge-mock` | スキル | 設計書とトンマナから画面モック HTML を生成する |
| `bridge-push` | スキル | スクショ再生成 → 画面イメージ更新 → Claude Design へ反映 → 記録解除 |
| `bridge-pull` | スキル | 明示指示時のみ。リモートと照合し、承認を得てローカルを更新する |
| `bridge-status` | スキル | 未反映一覧とドリフト状況を読み取り専用で表示する |
| `/design-init` `/design-mock` `/design-push` `/design-pull` `/design-status` | コマンド | 各スキルの明示起動 |
| PostToolUse フック | フック | 設計書・モックの変更を種別付きで記録する |
| Stop フック | フック | 未反映が残っていれば応答の終了をブロックする |

## 使い方

### 初回セットアップ後の構成

```text
<repo>/
├─ specs/screens/S001_login.md      # 画面設計書（正本）
├─ specs/assets/S001_login.png      # スクリーンショット（自動生成）
├─ mocks/_tokens.html               # トンマナ
├─ mocks/_layout.html               # 基礎レイアウト
├─ mocks/S001_login.html            # 画面モック（正本）
└─ .claude/design-bridge.json       # Claude Design との紐付け設定（コミット対象）
```

### 日常の流れ

```text
/design-mock S001_login     # 設計書からモックを生成
/design-push                # スクショ再生成 → 画面イメージ更新 → 反映
```

設計書やモックを編集したまま反映を忘れた場合、Stop フックが応答の終了をブロックして促します。同じ内容について既定 3 回通知すると、内容が変わるまで通知は止まります（作業が固着しないようにするためです）。

### 自然言語

| 発話例 | 起動 |
|-------|-----|
| 「このリポジトリに design-bridge を導入して」 | `bridge-init` |
| 「ログイン画面のモックを作って」 | `bridge-mock` |
| 「Claude Design に反映して」 | `bridge-push` |
| 「Claude Design 側の変更を取り込んで」 | `bridge-pull` |
| 「設計書とデザインのずれを確認して」 | `bridge-status` |

### 通知の強さを変える

同じ未反映について連続して通知する回数は既定 3 回です。変更する場合は利用者個人の設定ファイルに書きます。

```json
// ~/.claude/.local/plugins/design-bridge/user-config.json
{ "blockLimit": 1 }
```

1〜10 の範囲で指定できます。リポジトリ側の `.claude/design-bridge.json` には書けません（リポジトリを開いただけで他人の作業がブロックされる状態を避けるため）。

## ファイル構成

```text
plugins/design-bridge/
├── .claude-plugin/plugin.json
├── README.md
├── LICENSE
├── commands/                       # 5 コマンド
├── hooks/hooks.json
├── references/
│   ├── CLAUDE.md
│   └── scripts/
│       ├── CLAUDE.md
│       ├── hooks/                  # フック 3 本 + 共通ライブラリ + 回帰テスト
│       └── setup/                  # venv 構築・依存定義
└── skills/                         # 5 スキル（README / references / evals 付き）
```

## 依存システム（External Dependencies）

| システム | 用途 | 参照箇所 |
|---------|------|---------|
| claude.ai/design | 画面モックを design-system プロジェクトのカードとして表示・承認する | `skills/bridge-push/`、`skills/bridge-pull/` |

## 注意事項

### 名前が似ている別機能との区別

| 対象 | 何をするもの | 本プラグインとの関係 |
|-----|------------|------------------|
| 別マーケットプレイスの `design-sync` という名のスキル | 本番サーバーからフロントのリソースを取り込む | 無関係。取り込み元も方向も異なります |
| `coding` プラグインの `/design` コマンド | 実装・アーキテクチャの設計ワークフロー | 無関係。画面モックは扱いません |

### 仕組み上の制約

- `DesignSync` にリモート変更の通知機構がないため、`bridge-pull` と `bridge-status` のドリフト検出は、セッション中の自動検知ではなく明示実行時の照合として動作します
- 変更の検出は Edit / Write / MultiEdit を対象としています。`git pull` や `git checkout`、シェル経由の書き換えによる変更は記録されません
- スクリーンショット生成はオフラインのブラウザコンテキストで行うため、外部 CDN に依存するモックは画像化時にその部分が欠落します

## ライセンス

[MIT License](LICENSE) の下で配布されています。
