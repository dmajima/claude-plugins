# plugin-updater (skill)

Claude Code 公式 CLI（`claude plugin marketplace update` / `claude plugin update`）を経由して、インストール済みマーケットプレイスとプラグインを全スコープ（User / Project / Local）で一括最新化する実作業スキル。`/update-all` コマンドから委譲されて起動する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 責務（要約）

- Phase A-0 → G の固定順序での更新実行
- 横断ルール XR-1〜XR-5（入力検証 / タイムアウト / 出力サニタイズ / リトライ上限 / Unknown 警告）の適用
- Phase G の `AskUserQuestion` による失敗対応確認とリトライ
- Phase F のサマリ + 詳細テーブルによる結果報告

## 責務外

| 業務 | 担当 |
|-----|-----|
| 引数（`--dry-run` / `--scope`）の解釈・バリデーション | `commands/update-all.md`（呼び出し元コマンド） |
| `marketplace.json` / マーケットプレイス README の編集 | `extension-toolkit:marketplace-toolkit` |
| プラグインの新規公開 | `extension-toolkit:marketplace-publisher` |

## 導入手順

### 前提

- Claude Code がインストール済みで `claude plugin` サブコマンドが利用可能
- `plugins-update` プラグイン（このスキルを含む）がインストール済み
- Read / Bash / Grep / `AskUserQuestion` ツールが利用可能
- 依存プラグインなし

プラグイン全体の導入手順（マーケットプレイス経由 / ローカル複製 / 自動更新の有効化）は [`../../README.md`](../../README.md) を参照。

### 起動方法

本スキルは `/update-all` コマンド経由でのみ起動します（AI による自動起動は想定外）。

```text
/update-all
/update-all --dry-run
/update-all --scope user
/update-all --scope project
/update-all --scope local
```

`--dry-run` と `--scope` は併用可能。`--scope` 指定時もマーケットプレイス更新（Phase B）は常に実行されます。

## 利用方法

### 最小例

ユーザ:
> `/update-all`

Claude（要約）:
> Phase A 対象収集 → Phase B マーケットプレイス更新 → Phase C/D/E スコープ別プラグイン更新 → Phase F サマリ報告 → 失敗があれば Phase G で対応確認

### 応用例

| 目的 | コマンド | 動作 |
|-----|---------|------|
| 実行予定のみ確認（変更なし） | `/update-all --dry-run` | 実行予定 CLI コマンド一覧を表示。変更系 CLI は実行しない（ただし対象収集のため `settings.json` の Grep 読み取りと `marketplace list` は実行） |
| User スコープのみ更新 | `/update-all --scope user` | マーケットプレイス更新後、User スコープのプラグインのみ更新 |
| Project スコープのみ更新 | `/update-all --scope project` | マーケットプレイス更新後、Project スコープのプラグインのみ更新 |
| Local スコープのみ更新 | `/update-all --scope local` | マーケットプレイス更新後、Local スコープのプラグインのみ更新 |
| 失敗発生時の対応 | 失敗ありで実行完了 | Phase G で `AskUserQuestion` により再試行 / スキップ / 個別判断を確認 |

## 動作要件

| 要件 | 内容 |
|-----|------|
| Claude Code | `claude plugin marketplace update` / `claude plugin update` が利用可能なバージョン |
| 外部 CLI | `claude` コマンドが PATH 上で利用可能であること |
| ツール | Read / Bash / Grep / `AskUserQuestion` |
| 依存プラグイン | なし |

## 重要な制約

- **公式 CLI 経由限定**: `git fetch` / `git reset --hard` 等の低レベル git 操作は行わない（ADR-PU-002）
- **Phase 順序の厳守**: Phase A-0 → G の固定順序を入れ替えない（ADR-PU-003）
- **シークレット非接触**: `settings.json` 全文 Read は禁止。Grep + ブロック終端検出で `enabledPlugins` 以外のキーをメインコンテキストに載せない
- **Failed のみリトライ対象**: Missing は CLI リトライで回復しないため Phase G の対象外（ADR-PU-007）

## 起動コンテキスト

呼び出し元コマンドから以下を受け取ります。

| キー | 値の例 | 説明 |
|------|--------|------|
| `mode` | `normal` / `dry-run` | 通常実行か実行予定提示のみか |
| `scope` | `user` / `project` / `local` / `all` | 対象スコープ（`all` 既定） |

## ファイル構成

```text
skills/plugin-updater/
├── SKILL.md                              # スキル定義（Claude が読む）
├── README.md                             # このファイル
└── references/
    ├── phase-flow.md                     # Phase A-0〜G の固定順序・実行手順詳細（実行順序の SSOT）
    ├── cross-cutting-rules.md            # 横断ルール XR-1〜XR-5
    ├── output-formats.md                 # Phase F のテーブル / 警告 / 質問文フォーマット集
    └── architecture-decisions.md         # 設計判断記録 ADR-PU-001〜008
```

## 関連スキル / ドキュメント

| 用途 | 参照先 |
|-----|------|
| プラグイン全体の概要 | [`../../README.md`](../../README.md) |
| 呼び出し元コマンド | [`../../commands/update-all.md`](../../commands/update-all.md) |
| Phase 仕様の SSOT | [`references/phase-flow.md`](references/phase-flow.md) |
| 横断ルール SSOT | [`references/cross-cutting-rules.md`](references/cross-cutting-rules.md) |
| 出力フォーマット | [`references/output-formats.md`](references/output-formats.md) |
| 設計判断記録 | [`references/architecture-decisions.md`](references/architecture-decisions.md) |
| マーケットプレイス本体編集 | `extension-toolkit:marketplace-toolkit` |
| プラグイン公開 | `extension-toolkit:marketplace-publisher` |

## 設計上の特徴

- **コマンドとスキルの責務分離**: 引数解釈・トリガーは `/update-all` コマンド側、実作業は本スキル側（ADR-PU-008）
- **公式 CLI 経由限定**: 低レベル git 操作を排し、Claude Code の更新セマンティクスに完全準拠（ADR-PU-002）
- **サーキットブレーカー**: マーケットプレイス単位で累計 3 件以上の Failed が発生した場合、配下プラグインを Skip して連鎖失敗を抑止（ADR-PU-006）
- **シークレット非接触の対象収集**: `settings.json` の `enabledPlugins` のみを Grep + ブロック終端検出で抽出。他キーをメインコンテキストに載せない
