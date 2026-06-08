# マーケットプレイス対象チェックリスト

`.claude-plugin/marketplace.json` + マーケットプレイス直下 README を対象とするチェック項目（ADR-019 / ADR-020 準拠）。`common.md` の項目と併用すること。

## M-1. marketplace.json

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| M-1-1 | Critical | `marketplace.json` が JSON valid（パース可能） | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 2.8 |
| M-1-2 | High | `name` フィールドがリポジトリディレクトリ名と一致 | 同上 |
| M-1-3 | High | `plugins[]` の各エントリに `name` / `source` / `description` が必須項目として含まれる | 同上 |
| M-1-4 | Critical | 各 `plugins[].source` パスが実在する | 同上 |
| M-1-5 | High | 各 `plugins[].name` が `<source>/.claude-plugin/plugin.json` の `name` と完全一致する | 同上 |
| M-1-6 | Medium | バージョン情報を `marketplace.json` に持たせていない（`plugin.json` のみが正典） | 同上 |
| M-1-7 | Low | `plugins[]` がアルファベット順に整列されている | 同上 |

## M-2. allowCrossMarketplaceDependenciesOn

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| M-2-1 | High | クロスマーケットプレイス依存を持つプラグインがある場合、`allowCrossMarketplaceDependenciesOn` に依存先 MP 名が登録されている | [dependencies-policy.md](../../../references/policies/dependencies-policy.md) 節 3 |
| M-2-2 | Medium | `allowCrossMarketplaceDependenciesOn` の設定対象がマーケットプレイス側（`marketplace.json` のルート）にある | 同 節 3.3 |

## M-3. マーケットプレイス README（リポジトリルート）必須セクション

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| M-3-1 | Critical | 「## プラグイン一覧」セクションが存在する | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 2.8 / [readme-policy.md](../../../references/policies/readme-policy.md) 節 11.1 / ADR-019 |
| M-3-2 | Critical | プラグイン一覧テーブル行数 = `marketplace.json` の `plugins[]` 件数 | 同上 |
| M-3-3 | Critical | 各行のプラグイン名が `marketplace.json` と完全一致 | 同上 |
| M-3-4 | High | バージョン列が各 `<source>/.claude-plugin/plugin.json` の `version` と一致 | 同上 |
| M-3-5 | High | 「## マーケットプレイスの追加方法」セクションが存在し、A: URL / B: ローカル複製の **両方** が記載されている | [readme-policy.md](../../../references/policies/readme-policy.md) 節 11.1 |
| M-3-6 | High | 「## 自動更新の有効化」セクションが存在する（`extraKnownMarketplaces` の `autoUpdate: true` 設定例） | 同上 |
| M-3-7 | High | 依存マーケットプレイス（`allowCrossMarketplaceDependenciesOn` 非空時）の説明セクションが存在する | 同上 |

## M-4. プラグイン一覧テーブルの形式

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| M-4-1 | High | テーブルが `プラグイン / 説明 / バージョン / インストール` の列を持つ | [readme-policy.md](../../../references/policies/readme-policy.md) 節 11.1 |
| M-4-2 | High | バージョンが各プラグインの `plugin.json` から **直接転記** されている | 同上 |
| M-4-3 | High | インストールコマンドが `/plugin install {plugin-name}@{marketplace-name}` 形式で記載されている | 同上 |

## M-5. 同期義務（ADR-019）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| M-5-1 | High | `marketplace.json` 編集と **同一コミット** にマーケットプレイス README 変更が含まれる | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 2.8 / ADR-019 |
| M-5-2 | High | プラグイン新規追加・更新・削除のいずれにおいても README が同期されている | [readme-policy.md](../../../references/policies/readme-policy.md) 節 11.1 |
| M-5-3 | Medium | `marketplace-toolkit` または `marketplace-publisher` 経由で更新されている（手動編集よりツール経由を優先） | [architecture-decisions.md](../../../references/architecture/decisions-001-010.md) ADR-020 |

## M-6. レビューエージェント並列起動（マーケットプレイスレビュー時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| M-6-1 | High | 専用チームなし、個別 3 名（`marketplace-fit-reviewer`（リード）/ `plugin-structure-reviewer` / `architect`）並列起動された | [review-perspectives.md](../review-perspectives.md) 節 7 / [team-selection.md](../team-selection.md) |
| M-6-2 | High | `architect` 不在時のフォールバック（`plugin-structure-reviewer` がリード兼任、または `general-purpose` を `architect` 専門性プロンプトで起動）が実施されている | [review-perspectives.md](../review-perspectives.md) 節 7 |

## M-7. 重複・差別化（マーケットプレイス内の他プラグインとの整合）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| M-7-1 | High | `plugins[]` に同名エントリ衝突がない | [marketplace-fit-reviewer.md](../../../agents/marketplace-fit-reviewer.md) |
| M-7-2 | High | 既存プラグインと機能領域の重複がない、または差別化点が明示されている | 同上 |
| M-7-3 | High | 各プラグインの `dependencies` 各依存先が解決可能（同一 MP 内に存在 or `allowCrossMarketplaceDependenciesOn` 経由） | 同上 |
