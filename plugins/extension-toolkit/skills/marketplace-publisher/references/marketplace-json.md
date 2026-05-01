# marketplace.json スキーマ概要（参照ポインタ）

`.claude-plugin/marketplace.json` のスキーマと公式仕様の参照をまとめたドキュメント。

> **重要（ADR-020 準拠）**:
> `marketplace.json` の **編集操作**（plugins[] への追加 / 更新 / 削除、マーケットプレイス README 同期）は `marketplace-toolkit` が担当する SSOT である。本ファイルは `marketplace-publisher` が公開ワークフローを実行する際の **スキーマ参照** のみを目的とし、編集ロジックは保持しない。
>
> 編集操作の詳細手順は以下を参照:
>
> - [`../../marketplace-toolkit/SKILL.md`](../../marketplace-toolkit/SKILL.md)（責務全体）
> - [`../../marketplace-toolkit/references/operations.md`](../../marketplace-toolkit/references/operations.md)（モード別操作手順 SSOT）
> - [`../../marketplace-toolkit/references/readme-sync.md`](../../marketplace-toolkit/references/readme-sync.md)（README 同期ロジック）

## ファイルパス

```
<repo-root>/.claude-plugin/marketplace.json
```

## スキーマの最上位フィールド

| フィールド | 必須 | 内容 |
|----------|------|------|
| `name` | 必須 | マーケットプレイス名（リポジトリディレクトリ名と一致） |
| `owner.name` | 必須 | オーナー名 |
| `description` | 必須 | マーケットプレイスの目的・配布方針（1〜2 文） |
| `plugins[]` | 必須 | プラグインエントリ配列 |
| `allowCrossMarketplaceDependenciesOn` | 任意 | 依存先マーケットプレイス名のリスト |

## `plugins[]` エントリの形式

```json
{
  "name": "{plugin-name}",
  "source": "./plugins/{plugin-name}",
  "description": "{プラグインの 1〜2 文説明}"
}
```

| フィールド | 必須 | 内容 |
|----------|------|------|
| `name` | 必須 | プラグイン名（`<source>/.claude-plugin/plugin.json` の `name` と一致） |
| `source` | 必須 | リポジトリルートからの相対パス（`./plugins/` プレフィックス必須、パストラバーサル対策） |
| `description` | 必須 | 1〜2 文の概要 |

## バージョンに関する重要原則

- バージョン情報は `marketplace.json` に **記載しない**
- バージョンの正典は各プラグインの `<source>/.claude-plugin/plugin.json` の `version`
- マーケットプレイス README のプラグイン一覧テーブルのバージョン列も、`plugin.json` から **直接転記** する（`marketplace-toolkit` が同期）

## 並び順

`plugins[]` は **アルファベット順** で挿入する。並び順の管理は `marketplace-toolkit` 側で行う。

## marketplace-publisher が `marketplace.json` を扱う場面

`marketplace-publisher` が `marketplace.json` に対して直接行う操作は以下に **限定** される:

- **読み込み**: 重複検査・実体検証・公開フローの判断材料として
- **検証**: JSON valid / プラグイン名整合 / source パス実在 / README 同期確認
- **コミット範囲への含有**: `git add .claude-plugin/marketplace.json` を実行（変更したのは `marketplace-toolkit`）

**書き換え（plugins[] の追加・更新・削除）は本スキルの責務外**。`marketplace-toolkit` を Skill ツール経由で呼び出して実行する。

## 検証ルール

`marketplace.json` および関連 README の検証項目は [`../../../references/validation-rules.md`](../../../references/validation-rules.md) 節 2.8 を参照（`marketplace-toolkit` 出力検証として SSOT 化）。
