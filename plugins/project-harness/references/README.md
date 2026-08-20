# references/ ディレクトリ（人間向けインデックス）

project-harness プラグインのプラグイン共通リソース（SSOT）の人間向けインデックス。本ファイルはエージェント動作では使用されない（エージェント向けの原則・ナビゲーションは [`CLAUDE.md`](CLAUDE.md) が正典。各サブディレクトリの詳細は [`templates/CLAUDE.md`](templates/CLAUDE.md) / [`scripts/CLAUDE.md`](scripts/CLAUDE.md) を参照）。

## 構成

| パス | 内容 |
|------|------|
| [structure-spec.md](structure-spec.md) | 対象プロジェクトに構築する `.claude` ハーネスの構成仕様（フォルダ定義・CLAUDE.md 階層索引・frontmatter と sources 記法・命名・アーカイブ規則・モノレポ対応・仕様バージョン） |
| [authoring-spec.md](authoring-spec.md) | ドキュメント作成・索引維持・検証の共通規則（記載の原則・秘匿情報の非記載・未信頼入力の扱い・書き込み境界・検証項目） |
| [sync-spec.md](sync-spec.md) | 同期状態（`.sync-state.json`）・差分検出フロー・SessionStart 鮮度検知フック・全量監査モードの仕様 |
| [templates/](templates/) | 対象プロジェクトへ配置するドキュメント雛形 11 種 |
| [scripts/](scripts/) | フック実スクリプト（`hooks/freshness_check.sh`）と検証スクリプト（`validate/validate_harness.sh`） |

## SSOT とスキルの分担

| 知識 | 置き場所 |
|------|---------|
| ハーネス構成の定義 / 書き方と検証の共通規則 / 同期の仕組み / ドキュメント雛形 / スクリプト | 本ディレクトリ（SSOT） |
| 初期構築の実行手順・調査エージェント運用 | `skills/harness-init/references/` |
| 差分反映の実行手順・反映エージェント運用 | `skills/harness-update/references/` |

## 構築されるハーネスの全体像

`harness-init` は本ディレクトリの仕様と雛形に従い、対象プロジェクトへ次を生成する。

| 生成先 | 役割 |
|--------|------|
| `<repo-root>/CLAUDE.md` | ハーネス入口（`@.claude/CLAUDE.md` の import。既存があれば追記、無ければ最小スタブを作成） |
| `.claude/CLAUDE.md` | プロジェクト概要・技術スタック（常時読込・100 行以内） |
| `.claude/references/specs/` | 仕様設計書（画面遷移・画面構成・業務ルール・アプリ動作） |
| `.claude/references/system-designs/` | 詳細設計書（specs 対応・実装で詳細化すべき設計情報） |
| `.claude/references/flows/` | 画面位置・アクセス手順 |
| `.claude/references/environments/` | ビルド・テスト・起動・検証コマンド |
| `.claude/references/conventions/` | コーディング規約・命名・配置・コミット / PR 規約 |
| `.claude/references/architecture/` | システム構成・モジュール依存・データモデル |
| `.claude/references/decisions/` | ADR（設計判断記録） |
| `.claude/references/glossary.md` | ドメイン用語集 |
| `.claude/references/.sync-state.json` | 同期状態（最終同期コミット・通知閾値） |

## 拡張方法

1. ハーネスにフォルダ種別を追加する場合は [structure-spec.md](structure-spec.md) 節 9.1 の更新対象チェックリストに従う（節 2・3・5.1・templates・仕様バージョンを一括で更新する）
2. 追加種別の雛形を [templates/](templates/) に作成し、[templates/CLAUDE.md](templates/CLAUDE.md) の一覧へ登録する
3. 生成・同期の手順（`skills/harness-init/references/procedures.md` / `skills/harness-update/references/procedures.md`）を追随させる
4. 同期の判定ロジックを変える場合は [sync-spec.md](sync-spec.md) を更新し、[scripts/hooks/freshness_check.sh](scripts/hooks/freshness_check.sh) を追随させる
5. 検証項目を変える場合は [authoring-spec.md](authoring-spec.md) 節 6 を更新し、[scripts/validate/validate_harness.sh](scripts/validate/validate_harness.sh) を追随させる
