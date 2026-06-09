# コミット粒度・分割ルール（SSOT）

`extension-toolkit` プラグイン配下のすべての作成・改修作業（スキル・プラグイン・コマンド・エージェント・フック・マーケットプレイス・ドキュメント・スクリプト）が従うコミット分割ルール（ADR-031 準拠）。

このルールは **プラグイン内ルール** として配布される。利用者環境に依存しないため、誰がインストールしても同じ履歴可読性・部分ロールバック容易性を保証する。

---

## 1. 原則

### 1.1 「作業単位 = 1 コミット」を既定とする

1 つのコミットは **1 つの独立した作業単位** に対応させる。
複数の作業単位を 1 コミットにまとめることを禁止する。

| 良い例 | 悪い例 |
|--------|--------|
| `feat(maintenance): cleanup-workspace スキル新設` 単独 | `feat(maintenance): cleanup-workspace + sync-settings + README 更新` 同梱 |
| `refactor(extension-toolkit): plugins-update → maintenance:plugin-updater 改名` 単独 | 改名 + ロジック修正 + ADR 追加 同梱 |
| `docs(extension-toolkit): A-3 commit-granularity.md 追加` 単独 | A-3〜A-6 全 references 同梱 |

### 1.2 Conventional Commits 互換

すべてのコミットメッセージは Conventional Commits 形式の prefix を持つ。

| Prefix | 用途 |
|--------|------|
| `feat:` | 新規機能・新規スキル・新規ファイル追加 |
| `fix:` | バグ修正 |
| `refactor:` | 動作を変えないコード整理・改名・移動 |
| `docs:` | ドキュメント追加・更新（references / README / SKILL.md の文章変更） |
| `test:` | evals / テスト追加・修正 |
| `chore:` | バージョン番号・依存関係・ビルド設定等の機械的更新 |
| `perf:` | パフォーマンス改善 |
| `style:` | フォーマットのみ（コード意味変化なし） |

スコープ（括弧内）は **対象プラグイン名 / スキル名 / 機能名** を記載する。複数スコープにまたがる場合は分割する。

---

## 2. 分割すべき作業単位（必須分割対象）

以下の作業は **必ず別コミット** とする。1 コミットに混在させない。

| 作業単位 | 例コミット | 理由 |
|----------|----------|------|
| (a) ディレクトリ・ファイルのリネーム | `refactor(extension-toolkit): rename plugins-update to maintenance` | リネーム自体の検証可能性。git の `--follow` 履歴を保つため |
| (b) ファイル・ディレクトリの移管（プラグイン間移動） | `refactor(maintenance): move plugin-updater from plugins-update` | 移管前後で同一性を担保するため |
| (c) 内容の更新（本質的変更） | `feat(maintenance): plugin-updater Phase G 追加` | 機能変更を独立検証するため |
| (d) ADR（architecture-decisions.md）追加 | `docs(extension-toolkit): ADR-031 commit-granularity 追加` | 意思決定の独立な記録 |
| (e) README / marketplace.json の同期 | `docs(repo): README + marketplace.json に maintenance を追加` | 公開メタ情報の整合性をその単位で検証 |
| (f) 移行手順・廃止アナウンス記載 | `docs(maintenance): 旧プラグイン名からの移行手順を追加` | 利用者向けアナウンスの独立な可視化 |
| (g) evals 追加・拡張 | `test(plugin-updater): dry-run 8 ケース追加` | テスト追加を独立に検証 |
| (h) 機械チェック・lint 修正 | `fix(maintenance): argument-hint 60 文字超過 4 件修正` | 機械的修正を独立に取り出し |
| (i) 依存関係の更新 | `chore(extension-toolkit): PSScriptAnalyzer 依存追加` | 依存変更の独立な検証 |
| (j) バージョン番号の昇格 | `chore(maintenance): bump version to 0.3.0` | リリースタグ付与の単位 |

複数の改修を含む大規模変更（例: バックログの一括対応）でも、上記単位ごとに分割すること。

---

## 3. 1 コミットに同梱してよいケース

例外的に 1 コミットに含めてよい場合は限られる。

| 同梱可 | 条件 |
|--------|------|
| 単一の修正に必須な複数ファイル | 例: スキル新設時の SKILL.md + README.md + plugin.json への登録（同一の論理単位） |
| 改名と同時に行わないと壊れる相互参照の更新 | 改名コミットに含めてよいが、行数を最小化する |
| 仕様変更とそれに対応する evals 修正 | 仕様変更コミットに evals 更新を含めてよい（仕様変更検証のため） |

同梱の判断に迷う場合は **分割を選択** すること（過剰分割は許容、過剰同梱は不可）。

---

## 4. 大規模変更時のコミットチェーン例

### 4.1 例: 新規プラグイン作成（複数スキル含む）

```text
feat(plugin-name): plugin skeleton（plugin.json + LICENSE + README + .claude-plugin/）
feat(plugin-name): foo-skill 新設
feat(plugin-name): bar-skill 新設
feat(plugin-name): baz-skill 新設
test(plugin-name): foo-skill evals N ケース追加
test(plugin-name): bar-skill evals N ケース追加
test(plugin-name): baz-skill evals N ケース追加
docs(plugin-name): ADR-xxx 設計判断記録追加
docs(repo): marketplace.json + リポジトリ README に plugin-name を追加
chore(plugin-name): version 0.1.0 タグ付け
```

### 4.2 例: 既存プラグイン改名 + 内容更新

```text
refactor(repo): plugins/old-name → plugins/new-name へリネーム
refactor(new-name): SKILL.md 内の自己参照を旧名から新名に更新
docs(new-name): 旧プラグイン名からの移行手順を README に追加
feat(new-name): 改修内容（仕様変更があればここで個別に）
docs(repo): marketplace.json から old-name を削除し new-name を追加
docs(extension-toolkit): ADR-xxx 改名理由・互換性方針追加
```

### 4.3 例: 1 バックログの一括対応（10 項目）

```text
docs(extension-toolkit): A-3 commit-granularity.md 追加
docs(extension-toolkit): A-5 user-interaction AskUserQuestion 原則化
docs(extension-toolkit): A-6 askquestion-strategy.md 追加
docs(extension-toolkit): A-4 argument-policy.md 追加
docs(extension-toolkit): A-1 動作デモ承認フロー必須化 + ADR-031
docs(extension-toolkit): A-2 UI レビュー観点追加
feat(extension-toolkit): B-1 PSScriptAnalyzer 統合
feat(extension-toolkit): B-2 実行ベース evals CI 化
feat(extension-toolkit): B-3 デモテンプレート追加
docs(extension-toolkit): C-1 powershell-pitfalls.md SSOT 追加
docs(backlog): improvement-backlog DONE マーキング
```

---

## 5. ADR との関係

| 項目 | 配置先 | 1 コミット内同梱可否 |
|------|--------|---------------------|
| 設計判断の根拠（ADR 本体） | `references/architecture/` 内のセクション | **同梱可**: 同 ADR が動機付ける単一の実装変更と同コミットに含めてよい |
| 設計判断 + 実装の両方を伴う複数の変更 | 別コミットに分割 | **同梱不可**: 「ADR-xxx 追加」と「ADR-xxx に従う実装」は別コミット |

具体例:
- 1 つの ADR が 1 つの実装変更を動機付ける場合 → 同コミットに ADR 記載 + 実装変更を含めてよい
- 1 つの ADR が 3 つの実装変更（ファイル A・B・C）を生む場合 → 「ADR 追加」「A 実装」「B 実装」「C 実装」の 4 コミットに分割

---

## 6. 検証可能性の担保

各コミットは **そのコミット単独で意味が完結** すること。

| 確認項目 | 確認方法 |
|----------|----------|
| ビルド / lint が通る | `git rebase -i` でコミット単位に止めて検証可能か |
| プラグインがロード可能 | `plugin.json` の整合性 |
| evals が通る（仕様変更のみ） | 変更前後で evals が壊れていないか |
| マーケットプレイス整合性 | `marketplace.json` が同コミット内で整合しているか |

「次のコミットで直すから今は壊れていてもよい」は禁止。コミット間で `git bisect` が機能することを保証する。

---

## 7. 違反検出

現状は `extension-review` の **専門家レビュー（人間 / Agent）** で以下を確認する。
**機械検出スクリプトは ADR-031 初版時点で未実装**（git log 解析を伴うため、`references/scripts/checks/run_checks.py` とは別系統の検査スクリプトが将来追加される予定）。

| チェック | 検出対象 | 現状の実装 |
|----------|---------|---------|
| 1 コミット内のファイル変更数 | 大規模（> 20 ファイル）の場合は分割妥当性をレビューで判断 | 専門家レビューで実施 |
| 1 コミット内のスコープ混在 | コミットメッセージのスコープと変更ファイルパスの不一致 | 専門家レビューで実施（機械検出は将来実装） |
| ADR 追加と実装の同梱 | `architecture/` 配下 の変更行数とコミット全体行数の比率 | 専門家レビューで実施（機械検出は将来実装） |

違反が見つかった場合は **コミット分割を強く推奨** する（強制リバートはしない。利用者の git 履歴に対する裁量を尊重する）。

将来実装する機械検出スクリプトは `extension-review/references/scripts/checks/run_commit_granularity_check.py`（仮称）として追加し、`run_checks.py` の CHECKS リストに統合する設計を予定。

---

## 8. 例外と免責

| 例外 | 条件 |
|------|------|
| 緊急のセキュリティ修正 | 一時的に複数ファイルを 1 コミットに含めてよい。事後に必要なら分割リバート＋再コミット |
| 自動生成物の同期 | 例: `marketplace.json` の自動生成 + 元データ更新が常に同期している場合 |
| 利用者の明示的指示 | 利用者が「全部 1 コミットで」と明示した場合は本ルールを免責する |

---

## 9. 参照

- ADR-031（`architecture/` 配下）
- Conventional Commits 1.0.0 仕様
- [git-bisect](https://git-scm.com/docs/git-bisect) のドキュメント
