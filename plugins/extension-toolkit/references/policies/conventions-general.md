# 共通規約・禁止事項

`extension-toolkit` プラグイン配下の全スキル・全成果物が従うべき共通規約・禁止事項。

階層別の厳格度:

| 階層 | 厳格度 | 内容 |
|-----|-------|------|
| プラグイン直下 | **厳格（許可リスト運用）** | 列挙されたディレクトリ・ファイル以外を置かない |
| スキル直下 | **厳格（許可リスト運用）** | 同上 |
| `references/` 直下 | 推奨例（緩い） | 推奨される命名・配置を例示。実情に応じて拡張可 |
| `scripts/` 直下 | 推奨例（緩い） | 推奨される業務単位サブフォルダを例示。`knowledge/` 等の禁止項目のみ厳格 |

本ファイルは共通規約・禁止事項。命名規約は [`conventions-naming.md`](conventions-naming.md)、構造規約は [`conventions-structure.md`](conventions-structure.md) を参照。

## 8. references 内のファイル分離原則

`references/` 配下のファイルは以下の種別のいずれか 1 つに特化させ、同一ファイルに混在させない:

| 種別 | 配置先 | 内容 |
|-----|-------|------|
| ポリシー（制約・禁止） | `policies/` | 「何をしてはならないか」「何を守るべきか」 |
| ガイド（手法・指針） | `guides/` | 「どう設計・記述すべきか」のベストプラクティス |
| チェックリスト（検証項目） | `checklists/` | 検証項目の網羅確認 |
| 手順（ステップフロー） | `procedures/` | ステップバイステップの操作手順・OK/NG 例集 |
| テンプレート（ひな形） | `templates/` | コピーして利用する雛形 |
| ADR（設計決定） | `architecture/` | アーキテクチャ決定の理由・トレードオフ |

サイズ閾値: **200 行を目安上限、300 行超は分割必須**。
分割時は元ファイル・新ファイル双方に相互参照リンクを入れ、読者が来訪経路を辿れるようにする。

詳細な構造は [`conventions-structure.md`](conventions-structure.md) 節 4 を参照。

## 9. テンプレートの 2 階層管理

| 階層 | 配置 | 用途 |
|-----|-----|------|
| プラグイン横断 | `plugins/{plugin}/references/templates/{種別}/` | 全スキル共通の推奨構成 |
| スキル固有 | `plugins/{plugin}/skills/{skill}/references/template/` | そのスキルが生成する固有テンプレート |

スキル固有派生は **横断テンプレートをコピーしてから差分** を加える（ADR-003）。

## 9. パスポータビリティ

詳細は [`path-portability.md`](path-portability.md) を参照。

| 用途 | 変数 |
|-----|------|
| スキル自身のディレクトリ | `${CLAUDE_SKILL_DIR}` |
| プラグイン自身のルート | `${CLAUDE_PLUGIN_ROOT}` |
| プラグインの永続データ領域 | `${CLAUDE_PLUGIN_DATA}` |

ローカル絶対パスのハードコード禁止。

## 10. ファイル編集時のエンコーディング

既存ファイル更新時は **元ファイルのエンコーディング・改行コードを維持** する（文字化け防止）。詳細は `~/.claude/rules/common/file-encoding.md` を参照。

UTF-8 以外（Shift-JIS / CP932 等）のファイルは Edit / Write ツールを直接使用せず、Python 経由で書き戻す。

## 11. README.md ポリシー

詳細は [`../readme-policy.md`](../readme-policy.md) を参照。

- **すべてのプラグイン・スキルに必須**
- 人間向けリファレンス（Claude スキル動作では不参照）
- **常に最新版のみ記載**（過去履歴は Git 管理のため不要）
- 利用者向け導入手順を冒頭、技術スタック・アーキテクチャは後半
- `SKILL.md` / `references/` は `README.md` を参照しない（一方向参照）

## 12. 禁止事項（厳格・緩和を区別）

### 12.1 厳格な禁止（配置）

- プラグイン直下のディレクトリで [`conventions-structure.md`](conventions-structure.md) 節 2.1 に列挙されていないものを追加（ADR で明示する場合のみ例外）
- スキル直下に [`conventions-structure.md`](conventions-structure.md) 節 3.1 に列挙されていないディレクトリ・ファイルを置く（ADR で明示する場合のみ例外）

### 12.2 厳格な禁止（命名）

- `scripts/` の代わりに `knowledge/` `lib/` `bin/` 等を使用
- `references/` の代わりに `shared/` `common/` `docs/` 等を使用
- 拡張子別のサブフォルダ（`scripts/py/` `scripts/sh/` 等）

### 12.3 厳格な禁止（ファイル内容）

- `references/` 配下のファイルで 300 行超過（分割必須、節 8 参照）
- `references/` 配下の単一ファイルにルール・ガイド・チェックリスト・手順・テンプレートを混在（節 8 参照）
- `SKILL.md` 200 行超過（超過時は references に分離する）
- `agents/` ディレクトリの重複理由による削除（プラグイン配布先環境のため保持必須）
- ローカル絶対パスのハードコード（`${CLAUDE_*}` または相対パスを使う）
- `README.md` への過去履歴・変更経緯の記載（Git 管理のため不要）
- 動作分岐があるスキルでの `evals/` 省略
- `§` 記号の使用（代替: `1.` / `セクション1` / `第1節` 等）
- 構造化データの Markdown 表での長期保存（[`state-files.md`](state-files.md) 参照）

### 12.4 厳格な禁止（操作）

- 既存ファイル更新時のエンコーディング・改行コード変更
- ユーザ選択を AskUserQuestion 以外の方法で求める（重要な選択肢の場合）
- 作業完了報告前に [`../checklists/completion-checklist.md`](../checklists/completion-checklist.md) の自己検証を省略

### 12.5 厳格な禁止（ドキュメント履歴記載）

- プラグイン内ドキュメント（README / SKILL.md / references / evals 等）に自身の更新履歴を残すこと（[ADR-016](../architecture-decisions.md) 参照）
- 「当初は」「改訂」「Round-N で」「リネーム時点で」のような時系列記述
- 「## 変更履歴」「## Changelog」「## Release Notes」等のセクション
- 例外: ユーザから明示指示があった場合のみ履歴記載を許容

## 13. 検証

本規約のうち **[`conventions-structure.md`](conventions-structure.md) 節 2.1（プラグイン直下）と節 3.1（スキル直下）の許可リスト遵守** は [`../checklists/validation-rules.md`](../checklists/validation-rules.md) の機械チェックで自動検出する。`references/` 直下と `scripts/` 直下は推奨例のため機械チェック対象外（人間レビューで確認）。