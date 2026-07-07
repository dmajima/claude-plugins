# convert-doc references/

convert-doc プラグインの **プラグイン横断共通リソース** を集約するディレクトリの人間向けインデックス。

> エージェント向けの参照原則・ナビゲーションは [`CLAUDE.md`](CLAUDE.md) を参照
> （本 README は Claude のスキル動作では使用されません）。

## 内容

| パス | 種別 | 内容 |
|------|------|------|
| [`design-locations.md`](design-locations.md) | 規約（SSOT） | デザインアセット（CSS / HTML テンプレート / PPTX テーマ）の配置場所・探索順序・命名規則 |
| [`ruff.toml`](ruff.toml) | 設定 | `scripts/` 配下 Python スクリプトの静的解析設定 |
| [`scripts/`](scripts/) | 実行スクリプト | 変換本体・検証スクリプト・venv 構築（一覧は [`scripts/CLAUDE.md`](scripts/CLAUDE.md)） |

## 関連

- 各スキルの動作定義: `../skills/*/SKILL.md`
- プラグイン全体の人間向けリファレンス: [`../README.md`](../README.md)
