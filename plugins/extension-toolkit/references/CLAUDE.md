# extension-toolkit references/

Claude エージェントが extension-toolkit の作成・レビュー・公開作業を行う際に従う原則とナビゲーション。

## 目的と範囲

このディレクトリは extension-toolkit プラグイン横断の **SSOT（唯一の情報源）** を集約する。ポリシー・ガイド・チェックリスト・ADR・テンプレート・チーム定義・実行スクリプトを含む。

## 原則

1. **SSOT 優先**: ルールの正典は `policies/` 配下のファイルである。他ファイルは SSOT を参照し、重複記述しない
2. **ファイル種別の分離**: 1 ファイルに 1 種別（ポリシー / ガイド / チェックリスト / 手順 / テンプレート / ADR）。混在禁止
3. **200 行制約**: 各ファイルは 200 行以下。超過時は分割する
4. **ADR による変更管理**: 構造変更・新規ルール追加時は `architecture/` に ADR を追記してからルールを変更する
5. **README.md 参照禁止**: `README.md` は人間向け資料であり、エージェント動作で参照してはならない
6. **パスポータビリティ**: ファイル参照は相対パスを使用。絶対パス・環境変数・ドライブレターは禁止（`policies/path-portability.md`）
7. **スクリプトは `scripts/` に集約**: 実行可能ファイルは `references/scripts/` 配下にのみ配置（ADR-025）
8. **テンプレートは `templates/` に集約**: ひな形ファイルは `references/templates/` に配置。未解決の相対パスを含んでよい
9. **レビューはフレッシュ起動**: レビュー実施時は修正実装と同一コンテキストで行わない（`checklists/review-freshness.md`）

## ナビゲーション

| タスク | 最初に読む | 次に読む |
|-------|----------|---------|
| **スキルを新規作成する** | `policies/conventions-structure.md` 節 3 | `policies/conventions-naming.md` → `guides/description-guide.md` → `templates/skill/` |
| **プラグインを新規作成する** | `policies/conventions-structure.md` 節 2 | `policies/license-policy.md` → `templates/plugin/` |
| **コマンドを新規作成する** | `policies/conventions-structure.md` | `policies/argument-policy.md` → `templates/command/` |
| **レビューを実施する** | `checklists/validation-rules.md` | 対象種別の個別チェックリスト（`../skills/extension-review/references/checklists/`） |
| **バージョンを更新する** | `policies/versioning.md` | `../skills/extension-review/references/checklists/versioning.md` |
| **マーケットプレイスに公開する** | `policies/readme-policy.md` | `../skills/marketplace-publish/SKILL.md` |
| **ADR を追加する** | `architecture/` 配下の最新ファイル | `policies/conventions-general.md` 節 11 |
| **README を書く** | `policies/readme-policy.md` | `guides/readme-writing-guide.md` |
| **evals を書く** | `guides/eval-guide.md` | `templates/skill/evals/` |
| **MIT LICENSE を配備する** | `policies/license-policy.md` | `../skills/mit-license-toolkit/SKILL.md` |

## ディレクトリ構成

| ディレクトリ | 種別 | 参照タイミング |
|------------|------|-------------|
| `policies/` | 制約・禁止ルール | 作成・変更時に必ず確認 |
| `guides/` | 設計指針・ベストプラクティス | 設計判断時に参照 |
| `checklists/` | 検証項目 | 完了前・レビュー時に走査 |
| `procedures/` | 作業手順・例集 | 具体的な操作手順が必要な時 |
| `architecture/` | ADR | 構造変更の判断・根拠確認時 |
| `templates/` | ひな形 | 新規作成時にコピー元として使用 |
| `teams/` | チーム定義 | レビュー起動時にチーム編成を確認 |
| `scripts/` | 実行スクリプト | venv 構築・hook 実行・evals 実行時 |

## 禁止事項

- `README.md` をエージェント動作の参照先として使うこと
- SSOT 以外のファイルにルールの正典を記述すること
- `references/` 配下以外にナレッジファイルを配置すること
- ADR なしで構造規約を変更すること
