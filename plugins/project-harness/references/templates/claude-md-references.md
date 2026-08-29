# references/ ドキュメント索引

`.claude/references/` 配下のフォルダ一覧・用途・整理ルール。

## フォルダ一覧

| フォルダ | 用途 | 索引 |
|---------|------|------|
| `requirements/` | 要件定義書（背景・目的・スコープ・機能要求・非機能要求）。spec-first 運用時のみ存在 | [requirements/CLAUDE.md](requirements/CLAUDE.md) |
| `specs/` | 仕様設計書（画面遷移・画面構成・業務ルール・アプリ動作） | [specs/CLAUDE.md](specs/CLAUDE.md) |
| `system-designs/` | 詳細設計書（specs 対応・実装で詳細化すべき設計情報） | [system-designs/CLAUDE.md](system-designs/CLAUDE.md) |
| `flows/` | 画面位置・アクセス手順（URL・ナビゲーション経路・前提条件） | [flows/CLAUDE.md](flows/CLAUDE.md) |
| `environments/` | ビルド・テスト・起動・検証コマンドと環境構築手順 | [environments/CLAUDE.md](environments/CLAUDE.md) |
| `conventions/` | コーディング規約・命名・配置・コミット / PR 規約 | [conventions/CLAUDE.md](conventions/CLAUDE.md) |
| `architecture/` | システム構成・モジュール依存・データモデル | [architecture/CLAUDE.md](architecture/CLAUDE.md) |
| `decisions/` | ADR（設計判断記録） | [decisions/CLAUDE.md](decisions/CLAUDE.md) |
| `glossary.md` | ドメイン用語集 | （単一ファイル） |

{requirements/ を生成しない場合（code-first 構築で要件定義書を持たない場合）は、上表の requirements/ 行と「情報の置き場所」の requirements/ 行を削除する}

## ドキュメント整理ルール

### 情報の置き場所

| 情報の種類 | 置き場所 |
|-----------|---------|
| 「なぜ・何のために作るか」（背景・スコープ・機能要求・非機能要求） | `requirements/`（spec-first 運用時） |
| 「何を作るか」（機能仕様・業務ルール） | `specs/` |
| 「どう作るか」（クラス構成・処理フロー・データアクセス） | `system-designs/` |
| 「どこにあるか・どう到達するか」（画面の場所・導線） | `flows/` |
| 「どう動かす・確かめるか」（コマンド・環境） | `environments/` |
| 「どう書くか」（規約） | `conventions/` |
| 「全体はどうなっているか」（構成・依存・データ） | `architecture/` |
| 「なぜそうしたか」（判断の背景） | `decisions/` |
| 「言葉の定義」 | `glossary.md` |

### 記載規則

- 各ドキュメントは先頭に frontmatter（`title` / `sources` / `related` / `updated`、任意で `status`）を持つ
- `sources` には対応するソースコードパスのグロブを記載する（変更同期の検出キー）。未実装の仕様ドキュメント（`status: draft` / `agreed`）は `[]` とする
- `status` は仕様ライフサイクル状態（`draft` = 作成中 / `agreed` = 合意済み・実装待ち / `implemented` = 実装済み）。不在は `implemented` 扱い
- ファイル名は kebab-case。ADR のみ `ADR-NNN_<slug>.md` 形式
- 図解は mermaid 記法を使用する
- 未確認・不明箇所は `TODO:` として明示する（推測で記載しない）
- ファイルを追加・削除したら所属フォルダの `CLAUDE.md` 索引を必ず同期する

### 同期状態

`.sync-state.json` が最終同期コミットを保持する。開発が進んだら `/project-harness:update` で差分をハーネスへ反映する。
