# マーケットプレイス README 同期ロジック

`marketplace.json` の現状から、マーケットプレイス直下 `README.md` のプラグイン一覧テーブルおよび関連セクションを再生成する手順（ADR-019 準拠）。

## 同期対象セクション

| セクション | 必須 | 同期動作 |
|----------|------|---------|
| プラグイン一覧 | **必須** | `marketplace.json` の `plugins[]` から完全再生成 |
| マーケットプレイスの追加方法（A: URL / B: ローカル複製） | **必須** | 既存内容を保持、不足時はテンプレートから補完 |
| 自動更新の有効化 | **必須** | 既存内容を保持、不足時はテンプレートから補完 |
| プラグイン追加手順（メンテナ向け） | 推奨 | 既存内容を保持 |
| ライセンス・連絡先 | 任意 | 既存内容を保持 |

## プラグイン一覧テーブルの再生成

### テーブル形式

```markdown
| プラグイン | 説明 | バージョン | インストール |
|----------|------|----------|----------|
| `{name}` | {description} | {version} | `/plugin install {name}@{marketplace-name}` |
```

### 各列の取得元

| 列 | 取得元 | 補足 |
|---|--------|------|
| プラグイン名 | `marketplace.json` の `plugins[].name` | バッククォート囲み |
| 説明 | `marketplace.json` の `plugins[].description` | プレーンテキスト |
| バージョン | `<source>/.claude-plugin/plugin.json` の `version` | **直接転記**、`marketplace.json` には保持しない |
| インストール | 固定形式 `/plugin install {name}@{marketplace-name}` | `{marketplace-name}` は `marketplace.json` の `name` |

### 並び順

`marketplace.json` の `plugins[]` 配列順（アルファベット順を維持していることが前提）。

## 同期手順

```python
# 擬似コード
import json, pathlib

def sync_marketplace_readme(repo_root: pathlib.Path):
    # 1. marketplace.json 読込
    mp_json = repo_root / ".claude-plugin/marketplace.json"
    with open(mp_json, encoding="utf-8") as f:
        mp = json.load(f)

    marketplace_name = mp["name"]

    # 2. プラグイン一覧テーブル生成
    rows = []
    for entry in mp["plugins"]:
        plugin_json_path = repo_root / entry["source"] / ".claude-plugin/plugin.json"
        with open(plugin_json_path, encoding="utf-8") as f:
            pj = json.load(f)
        version = pj["version"]
        install_cmd = f"`/plugin install {entry['name']}@{marketplace_name}`"
        rows.append(f"| `{entry['name']}` | {entry['description']} | {version} | {install_cmd} |")

    table = "\n".join(rows)

    # 3. README.md 内のテーブルを置換
    readme = repo_root / "README.md"
    with open(readme, encoding="utf-8") as f:
        content = f.read()

    # マーカー間（後述）の内容を再生成テーブルで置換
    new_content = replace_section(content, "## プラグイン一覧", table)

    with open(readme, "w", encoding="utf-8") as f:
        f.write(new_content)
```

## セクション境界の検出

セクションは `## ` 始まりの見出しで区切る。マーケットプレイス README のテーブルは `## プラグイン一覧` の見出し直下に配置されることを前提とする。

セクション内の説明文（テーブル前の前置きテキスト）は保持し、テーブル本体のみ置換する:

```markdown
## プラグイン一覧

各プラグインの詳細は `plugins/{plugin-name}/README.md` を参照してください。  ← 保持

| プラグイン | 説明 | バージョン | インストール |  ← ここから
| ... | ... | ... | ... |                                              ← ここまでを置換
```

## 不足セクションの補完

`README.md` に必須セクションが欠落している場合、[`../../../references/templates/marketplace/README.md`](../../../references/templates/marketplace/README.md) から該当部分をコピーして補完する:

| 欠落セクション | 補完元 |
|------------|-------|
| マーケットプレイスの追加方法 | テンプレートの「## マーケットプレイスの追加方法」 |
| 自動更新の有効化 | テンプレートの「## 自動更新の有効化（推奨）」 |
| プラグイン一覧見出し | テンプレートの「## プラグイン一覧」 |

補完後はユーザに通知（差分提示）し、確認を得る。

## 検証

同期後に以下を確認:

- [ ] テーブル行数 = `marketplace.json` の `plugins[]` 件数
- [ ] テーブル各行のプラグイン名が `marketplace.json` と一致
- [ ] バージョン列が各 `plugin.json` の `version` と一致
- [ ] インストールコマンドが固定形式 `/plugin install {name}@{marketplace-name}`
- [ ] 必須セクション（A/B/C）が揃っている

## 同期失敗時の対処

| エラー | 対処 |
|-------|------|
| プラグインの `plugin.json` が見つからない | エラーメッセージ + 該当エントリをスキップせず処理中断（不整合を放置しない） |
| `marketplace.json` の JSON エラー | 修復前に同期不可、エラー終了 |
| README に該当セクションがなく、補完もできない | テンプレートから新規生成を提案 |
