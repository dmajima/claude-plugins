# 外部プラグイン依存ルール（SSOT）

プラグインが他のプラグインに依存する場合の宣言・設定ルール。

## 1. 依存の種別

| 種別 | 内容 | 宣言場所 |
|-----|------|--------|
| **必須依存** | 当該プラグインの動作に必須 | `plugin.json` の `dependencies` |
| **推奨依存** | 推奨される協力関係（あると機能拡張） | `plugin.json` の `dependencies`（任意） |
| **任意依存** | 利用者が選んで使う（参考実装等） | README に記載のみ |

## 2. `plugin.json` の `dependencies`

### 2.1 書式

```json
{
  "dependencies": [
    "plugin-name",
    {
      "name": "plugin-name",
      "version": ">=1.0.0",
      "marketplace": "marketplace-name"
    }
  ]
}
```

| フィールド | 必須 | 内容 |
|----------|------|------|
| 文字列のみ | - | プラグイン名のみ（同一マーケットプレイス内、バージョン指定なし） |
| オブジェクトの `name` | 必須 | プラグイン名 |
| `version` | 任意 | semver 範囲（`~1.2.3`, `^1.0`, `>=1.0.0` 等） |
| `marketplace` | クロス時必須 | 別マーケットプレイスを指定する場合のみ |

### 2.2 同一マーケットプレイス内依存

```json
{
  "dependencies": ["other-plugin-in-same-marketplace"]
}
```

`marketplace` 省略可。自動インストールされる（同一マーケットプレイス内は許可設定不要）。

### 2.3 クロスマーケットプレイス依存

```json
{
  "dependencies": [
    {
      "name": "example-skills",
      "marketplace": "anthropic-agent-skills"
    }
  ]
}
```

`marketplace` 必須。インストール時、依存先マーケットプレイスからの自動インストールには **`allowCrossMarketplaceDependenciesOn` の許可が必要**（次節）。
さらに **利用者側で依存先マーケットプレイスが `/plugin marketplace add` 済みでない場合、Claude Code 公式仕様により依存は未解決のまま放置される**（自動マーケ追加機構なし）。
このためクロスマーケットプレイス依存（`marketplace` フィールド値が自プラグインの所属マーケ名と異なる場合）があるプラグインは、README の「導入手順 D」に **依存マーケ追加コマンド + `extraKnownMarketplaces` 登録テンプレート + 依存プラグイン個別インストール** の 3 ブロックを必須記載すること（[ADR-028](../architecture/)、[`readme-policy.md`](readme-policy.md) セクション 5.1 D 参照）。

## 3. `marketplace.json` の `allowCrossMarketplaceDependenciesOn`

### 3.1 書式

```json
{
  "name": "{marketplace-name}",
  "owner": { "name": "{owner}" },
  "description": "...",
  "allowCrossMarketplaceDependenciesOn": ["other-marketplace-1", "other-marketplace-2"],
  "plugins": [...]
}
```

| フィールド | 内容 |
|----------|------|
| `allowCrossMarketplaceDependenciesOn` | クロスマーケットプレイス依存を許可するマーケットプレイス名の配列 |

### 3.2 動作

| 状況 | 動作 |
|-----|------|
| 配列に依存先マーケットプレイス名が **含まれる** | 自動インストール許可 |
| 配列に依存先マーケットプレイス名が **含まれない** | 自動インストールがブロックされ、利用者に手動インストールを求める |
| フィールドが **不在** | クロスマーケットプレイス依存はすべてブロック |

### 3.3 設定対象

許可フィールドは **マーケットプレイス側** に書く（プラグイン側ではない）。`marketplace.json` のルートに記載する。

## 4. 設定する判断基準

| 状況 | dependencies | allowCrossMarketplaceDependenciesOn |
|-----|--------------|-----------------------------------|
| プラグイン X が同一 MP の Y を必要 | `["Y"]` | 不要 |
| プラグイン X が別 MP の Y を必要 | `[{name: "Y", marketplace: "{MP}"}]` | 必要（`["{MP}"]`） |
| プラグイン X が別 MP の Y を **任意で** 利用 | dependencies に書かない（README で案内） | 不要 |
| プラグイン X が別 MP の Y を **強く推奨** | dependencies に書く + MP 側で許可 | 必要 |

## 5. 任意依存の README 記載

`dependencies` に書かない場合は README で明示する:

```markdown
## 任意依存

以下のプラグインがインストールされていると、追加機能が利用できます:

- `example-skills@anthropic-agent-skills`: スキル雛形参照
- `document-skills@anthropic-agent-skills`: ドキュメント生成

未インストールでも本プラグインは動作します。
```

## 6. version 指定の方針

| 戦略 | 例 | 用途 |
|-----|---|------|
| 厳密一致 | `"version": "1.2.3"` | バグ修正でも壊れる懸念がある場合（避ける） |
| パッチ許容 | `"version": "~1.2.0"` | 1.2.x のパッチを許容 |
| マイナー許容 | `"version": "^1.2.0"` | 1.x.x の新機能を許容（後方互換期待） |
| 範囲指定 | `"version": ">=1.0.0 <3.0.0"` | 特定範囲のみ |
| 指定なし | `"version"` を省略 | どのバージョンでも可 |

通常は `^1.x.x`（マイナー許容）または指定なしを推奨。

## 7. 依存解決ルール

| 状況 | 動作 |
|-----|------|
| 複数のプラグインが同じ依存を持つ | semver 範囲の **交差** を取り、満たす最高版をインストール |
| 範囲が交差しない | エラー（解決不可） |
| 必須依存が見つからない | プラグイン自体のインストール失敗 |

## 8. 検証

`plugin.json` 更新後の確認:

- [ ] `dependencies` 配列が valid JSON
- [ ] 各オブジェクトに `name` が含まれる
- [ ] クロスマーケットプレイス依存には `marketplace` が含まれる
- [ ] `version` 範囲が semver 構文に従う
- [ ] 対応する MP の `marketplace.json` に `allowCrossMarketplaceDependenciesOn` がある（クロス依存時）
- [ ] クロスマーケットプレイス依存時（`marketplace` フィールド値 ≠ 自プラグイン所属マーケ名）、README の導入手順 D に依存マーケ追加 + `extraKnownMarketplaces` 登録 + 依存プラグイン個別インストールの 3 ブロックが揃っている（ADR-028）

## 9. 既存ファイルとの整合

| 既存記述 | 反映 |
|---------|------|
| README の「依存システム」セクション | `dependencies` に必須依存を移し、README は概要記述に |
| SKILL.md の「依存外部スキル」セクション | スキル単位の任意参照は SKILL.md 維持、プラグイン全体の必須依存は plugin.json |

## 10. 禁止事項

- 必須依存を `dependencies` に宣言せず READMEのみに書くこと
- `version` 範囲を厳密一致（`"1.2.3"`）でハードコードすること（バグ修正で壊れる）
- クロスマーケットプレイス依存で `marketplace` を省略すること
- マーケットプレイス側で許可していないクロス依存を宣言すること

## 11. 参照

| 用途 | リンク |
|-----|------|
| 公式仕様（プラグイン依存） | https://code.claude.com/docs/en/plugin-dependencies.md |
| 公式仕様（プラグインマニフェスト） | https://code.claude.com/docs/en/plugins-reference.md |
