# plugins-update

Claude Code 公式 CLI（`claude plugin marketplace update` / `claude plugin update`）を経由して
**マーケットプレイスとインストール済みプラグインを全スコープ（User / Project / Local）で一括更新**
するメンテナンスプラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がプラグイン動作中に参照することはありません。
コマンド本体は `commands/update-all.md`（トリガーと引数解釈のみ）を、実作業手順は
`skills/plugin-updater/SKILL.md` および同 `references/` 配下を参照してください。
コマンドとスキルの責務分離は ADR-PU-008 を参照。

## 提供コマンド

| コマンド | 効果 |
|---------|-----|
| `/update-all` | 全マーケットプレイスとプラグインを最新版に更新し、再起動を促す |
| `/update-all --dry-run` | 実行予定の CLI コマンド一覧のみ表示。実際の更新は行わない |
| `/update-all --scope user` | マーケットプレイス更新後、User スコープのプラグインのみ更新 |
| `/update-all --scope project` | マーケットプレイス更新後、Project スコープのプラグインのみ更新 |
| `/update-all --scope local` | マーケットプレイス更新後、Local スコープのプラグインのみ更新 |

`--scope` 指定時も **マーケットプレイス更新（Phase B）は常に実行** されます。
`--dry-run` と `--scope` は併用可能。

## 導入手順

### 前提

- Claude Code がインストール済みで `claude plugin` サブコマンドが利用可能であること
- 後述「動作要件」のツールが PATH に通っていること
- 依存プラグインなし（`plugin.json` で `dependencies: []` を明示）

### A. マーケットプレイス経由でインストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install plugins-update@dmajima-claude-plugins
```

リリースタグの GPG 署名検証を行いたい場合は `git tag -v <tag>` を併用してください
（本リポジトリは現状署名運用なし）。

### B. ローカル複製でインストール（オフライン環境）

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. リリースタグまたは main に切替
cd <local-path>
git checkout <tag-or-branch>   # 例: git checkout v2.2.0 / git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. インストール
/plugin install plugins-update@dmajima-claude-plugins
```

### C. 自動更新の有効化（推奨）

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、
Claude Code セッション起動時に本プラグインが自動更新されます。

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

`autoUpdate: false` の場合や未設定時は、以下を手動実行することで最新化できます:

```text
/plugin update plugins-update@dmajima-claude-plugins
```

`autoUpdate: true` の状態でも、本プラグインの `/update-all` を **任意タイミングで手動実行** することで、
セッション中に最新化したい場合に対応できます。

### D. 依存関係

依存プラグインなし（`dependencies: []` を `plugin.json` で明示）。
個別インストール手順の追加は不要です。

### 動作確認

インストール直後の確認には `--dry-run` を使用します:

```text
/update-all --dry-run
```

実行予定の CLI コマンド一覧が表示され、実際の更新は行われません。

## 利用方法

### 最小例

ユーザ:
> 全部のプラグインを最新にして

Claude（要約）:
> Phase A〜G を順次実行し、`claude plugin marketplace update` と `claude plugin update <plugin>@<marketplace> --scope <scope>` を呼び出して全マーケットプレイス・全スコープのプラグインを更新。結果サマリと「次のアクション」を提示し、`/reload-plugins` か再起動を促す。

### 利用例

#### 通常更新

```text
/update-all
```

実行後、すべてのマーケットプレイスとプラグインが公式 CLI で最新化され、
更新結果テーブルが表示されます。最後に `/reload-plugins` または Claude Code 再起動を促されます。

#### 確認のみ（dry-run）

```text
/update-all --dry-run
```

実行予定の CLI コマンド一覧のみ表示され、実際の更新は行われません。
本番更新前の影響範囲確認に使えます。

#### スコープ限定更新

```text
/update-all --scope user
```

マーケットプレイス更新後、User スコープ（`~/.claude/settings.json` の有効プラグイン）のみを対象に更新します。

#### dry-run + スコープ限定

```text
/update-all --dry-run --scope project
```

Project スコープに限定した実行予定コマンドのみを表示します。

## 動作要件

| 動作要件 | 説明 |
|---------|-----|
| Claude Code CLI | `claude plugin marketplace update` / `claude plugin update` を実行するため必須。Phase A-0-2 で存在チェック + 必要サブコマンドの **正規表現照合**（`^\s+marketplace\s+update\b` 等）を行い、不在または不正実装時はエラーで中断 |
| Git CLI | マーケットプレイスを Git ソース（GitHub/git）で登録する場合に必要（Claude Code CLI 内部で利用） |
| `/reload-plugins` | 本コマンド完了後、セッションへの反映に使用 |

**セキュリティ推奨**: PATH 改変攻撃（同名シムによる差し替え）を防ぐため、利用前に `which claude`
（POSIX）/ `Get-Command claude`（Windows PowerShell）で実行バイナリの絶対パスを確認し、
OS パッケージマネージャ管理下に存在することを確認してください。

## 動作概要

`/update-all` コマンドはトリガー / 引数解釈のみを担当し、実作業は `plugin-updater` スキルへ
委譲します（ADR-PU-008）。Phase 構成の概略は以下のとおり（詳細は
`skills/plugin-updater/references/phase-flow.md` を参照）。

テーブルは **実行順** に並んでいます（A-0 → A → A-1 → A-2 → B → C → D → E → F → G、ADR-PU-003 準拠）。

| 実行順 | Phase | 処理内容 | 使用 CLI |
|-------|-------|---------|---------|
| 1 | A-0-1 | 引数バリデーション（`--scope` 値のホワイトリスト照合） | — |
| 2 | A-0-2 | Claude Code CLI 存在チェック | `claude plugin --help` |
| 3 | A | 対象収集（マーケットプレイス一覧 + 各スコープの `enabledPlugins`） | `claude plugin marketplace list` |
| 4 | A-1 | プラグイン名・MP 名・スコープ名の入力検証（XR-1） | — |
| 5 | A-2 | マーケットプレイス整合性検証（未登録 MP の早期除外） | — |
| 6 | B | マーケットプレイス更新（`--scope` 指定時も常に実行） | `claude plugin marketplace update` |
| 7 | C | User スコープのプラグイン更新 | `claude plugin update <plugin>@<marketplace> --scope user` |
| 8 | D | Project スコープのプラグイン更新 | 同上 `--scope project` |
| 9 | E | Local スコープのプラグイン更新 | 同上 `--scope local` |
| 10 | F | 結果報告（サニタイズ + サマリ + マーケットプレイス詳細 + スコープ別詳細） | — |
| 11 | G | 失敗があれば `AskUserQuestion` でリトライ / スキップを確認 | — |

### 横断ルール

各 Phase は以下 5 つの横断関心事に従います（規則本体・閾値・例外条項は
`skills/plugin-updater/references/cross-cutting-rules.md` を参照）。

| ID | ルール |
|----|------|
| XR-1 | 入力検証（プラグイン名・MP 名・スコープの正規表現照合 + ホワイトリスト + NFKC 正規化 + パス検証） |
| XR-2 | タイムアウト + サーキットブレーカー（個別 60 秒・全体 30 分・MP 単位累計 3 件 Failed で配下 Skip） |
| XR-3 | 出力サニタイズ（**主要パターン**: GitHub PAT / AWS / JWT / SSH URL / .netrc / SSH 鍵 / URL 埋め込み認証 等多数 + 40 字超デフォルトマスク。**「主要」の選定基準** = SKILL.md / ADR で個別言及されているもの、または利用頻度上位（5〜7 例）。**網羅的なパターン一覧は `skills/plugin-updater/references/cross-cutting-rules.md` の XR-3 サニタイズ規則本体テーブルを SSOT として参照**。新規パターン追加時は SSOT のみを更新し、本 README の「主要」リストは SKILL.md / ADR 言及状況に応じて選別更新する） |
| XR-4 | リトライ上限（最大 1 回 = 合計 2 試行） |
| XR-5 | Unknown 警告閾値（試行済みの 20% 超で警告） |

### 振る舞いの原則

設計判断の決定本文は `references/architecture-decisions.md` を参照してください。本一覧は ADR への索引です。

| 原則 | 根拠 ADR |
|-----|---------|
| 単一プラグイン化（独立配布・依存ゼロ） | ADR-PU-001 |
| 公式 CLI 経由 | ADR-PU-002 |
| Phase A-0〜G 固定順序 + スコープ個別更新 + 継続実行 | ADR-PU-003 |
| 横断ルール SSOT 配置 | ADR-PU-004 |
| exit code 一次判定 + Unknown 区分（Missing はリトライ対象外） | ADR-PU-005 |
| サーキットブレーカー（MP 単位累計 3 件） | ADR-PU-006 |
| 失敗対応の対話モデル（Failed のみリトライ・5 件閾値で個別判断除外） | ADR-PU-007 |
| コマンドとスキルの責務分離（トリガー / 実作業） | ADR-PU-008 |

## 技術スタック・アーキテクチャ

設計判断の詳細は次を参照してください:

- [`skills/plugin-updater/SKILL.md`](skills/plugin-updater/SKILL.md) — 実作業スキルの概要
- [`skills/plugin-updater/references/architecture-decisions.md`](skills/plugin-updater/references/architecture-decisions.md) — ADR-PU-001〜008
- [`skills/plugin-updater/references/cross-cutting-rules.md`](skills/plugin-updater/references/cross-cutting-rules.md) — XR-1〜XR-5 の SSOT
- [`skills/plugin-updater/references/phase-flow.md`](skills/plugin-updater/references/phase-flow.md) — Phase A-0〜G 詳細手順
- [`skills/plugin-updater/references/output-formats.md`](skills/plugin-updater/references/output-formats.md) — Phase F の出力フォーマット集

### バージョン同期方針

本プラグインのバージョンは `plugin.json` の `version` フィールドが **唯一の正典** です
（親マーケットプレイス側の `extension-toolkit:ADR-019`「marketplace.json の version 排除と
plugin.json への一元化」準拠）。`marketplace.json` のエントリにはバージョンを持たせず、
マーケットプレイス README のテーブルに表示されるバージョンは `plugin.json` から手動同期します。
差異検出時は `plugin.json` の値を信頼してください。

> 親マーケットプレイス側の ADR は `<repo-root>/marketplace-rules/` または `extension-toolkit`
> プラグイン配下の `references/architecture-decisions.md` を参照してください。

## 注意事項

- 本コマンドは Claude Code 公式 CLI に処理を委譲します。`git reset --hard` 等の低レベル操作は
  行わないため、マーケットプレイスのローカル複製で **手動編集や独自ブランチが意図せず破壊される心配はありません**。
- プライベートリポジトリのマーケットプレイスは、Git credential helper / SSH キーの設定が前提です。
  認証エラー時の詳細メッセージは CLI 出力に依存しますが、Phase F の結果報告では認証情報・URL 埋め込み
  トークン・SSH 鍵パス・ローカルパス内のユーザ名等を **マスクして表示** します。
- **サプライチェーンリスク**:
  - マーケットプレイス更新により新しい `hooks` / `commands` / `agents` / MCP サーバが
    引き込まれた場合、次回 Claude Code 起動時に **自動実行される** 可能性があります。
  - `--dry-run` で確認できるのは「実行する CLI コマンド」だけで、引き込まれる **新規 hooks の内容は
    確認できません**。再起動前に `claude plugin show <plugin>@<marketplace>` を個別に実行し、
    `hooks` セクションの差分を必ず確認してください。
  - 信頼するマーケットプレイスのみで本コマンドを使用してください。
- `autoUpdate: true` で十分な場合、本プラグインを使う必要はありません（セッション起動時に自動更新されます）。
  本プラグインは「セッション中に最新版を取り込みたい」場面のために設計されています。
  `autoUpdate: true` 起動時自動更新と `/update-all` 手動更新が同時に走った場合、CLI 内部のロック挙動に
  依存します（一方が待機する想定）。
- `claude plugin update` は **再起動が必要** と公式が明示しているため、本コマンド完了後は
  `/reload-plugins` か Claude Code 再起動が必要です。

## ロールバック手順

更新後に問題が発覚した場合の復旧手順:

1. `claude plugin uninstall <plugin>@<marketplace>` で問題のあるプラグインをアンインストール
2. マーケットプレイスの旧版に戻す（必要な場合）
   - **リモートマーケットプレイス**: ローカル複製を作成し旧タグへ固定
     ```bash
     git clone <marketplace-url> <local-path>
     cd <local-path>
     git checkout <旧タグ or 旧コミットハッシュ>
     ```
     その後 `/plugin marketplace add <local-path>` で別マーケットプレイスとして登録
   - **ローカルマーケットプレイス**: 該当ディレクトリで `git checkout <旧タグ>`
3. `claude plugin install <plugin>@<marketplace>` で旧版から再インストール
4. `/reload-plugins` または Claude Code 再起動

### タグ非存在時のフォールバック

リリースタグが切られていないマーケットプレイスでは、過去の commit ハッシュを直接指定:

```bash
git log --oneline    # 復旧したい時点のハッシュを特定
git checkout <commit-hash>
```

### マーケットプレイス本体が壊れた場合のリセット

`marketplace.json` 不整合等で読み込み不能になった場合:

```text
/plugin marketplace remove <marketplace-name>
/plugin marketplace add <url-or-local-path>
```

その後、必要なプラグインを再インストール。

マーケットプレイス本体（`marketplace.json` / 構成プラグイン群）の自動ロールバック機能は公式 CLI に
存在しないため、上記のように **ローカル複製 + git checkout** での代替が現実的です。

## ファイル構成

```text
plugins-update/
├── .claude-plugin/
│   └── plugin.json                              # プラグイン定義
├── README.md                                     # このファイル（人間向けリファレンス）
├── commands/
│   └── update-all.md                             # /update-all コマンド本体（トリガー + 引数解釈のみ）
└── skills/
    └── plugin-updater/
        ├── SKILL.md                              # 実作業スキル本体（Phase A-0〜G 概要）
        └── references/
            ├── phase-flow.md                     # Phase A-0〜G 詳細手順
            ├── output-formats.md                 # Phase F のテーブル / 警告 / 質問文フォーマット
            ├── cross-cutting-rules.md            # XR-1〜XR-5（横断ルール SSOT）
            └── architecture-decisions.md         # ADR-PU-001〜008（設計判断記録）
```

## 関連プラグイン

| プラグイン | 関係 |
|----------|-----|
| `extension-toolkit:marketplace-toolkit` | マーケットプレイス本体（`marketplace.json` / README）の管理 |
| `extension-toolkit:marketplace-publisher` | マーケットプレイスへのプラグイン公開ワークフロー |

## 関連ルール

- 自動更新ポリシー: `~/.claude/rules/claude/plugin-auto-update.md`（`autoUpdate: true` 必須・週 1 回更新チェック）

## ライセンス

本プラグインは MIT License で配布されます。
