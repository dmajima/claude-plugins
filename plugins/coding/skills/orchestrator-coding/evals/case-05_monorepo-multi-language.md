# Case 05: 複数言語モノレポでの言語スキル併用

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「プロフィール編集機能を追加して。フロントの画面とバックエンド API の両方」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | モノレポ: `apps/web/`（Nuxt 4 + TypeScript + Tailwind）と `api/`（Flask + SQLAlchemy + PostgreSQL） |

## 期待動作

### Phase 2: Analyze
- 各パッケージルートのマーカーを走査し、**検出されたすべての言語スキル・FW プロファイルを併用**:
  - `apps/web/`: coding-typescript + SSOT frameworks/vue.md（Nuxt）+ coding-css + SSOT frameworks/frontend-tooling.md（Tailwind）
  - `api/`: coding-python（frameworks/python-web.md 含む）+ SSOT frameworks/orm.md（SQLAlchemy）+ coding-sql（postgresql.md）
- 変更対象ごとに主スキル / 副スキルを区別して記録
- 規約解決は **パッケージごと** に実施（web と api で異なる .editorconfig / リンター設定を持ちうる）

### Phase 4: Implement
- フロント側は TS/Vue 規約、API 側は PEP 8 系規約と、ファイルの属するパッケージの規約で実装
- 検証もパッケージごとのツールチェーン（`nuxt build` 系 / `pytest` 系）で実施

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | impact-analysis.md の検出表に両パッケージの適用スキルが根拠付きで併記される |
| 生成コード | 各パッケージの規約に準拠（言語間で規約が混ざらない） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは 検出言語数 = 複数（モノレポ）である。skill-index.md 検出優先順位 4「検出されたすべての言語スキルを併用」が適用される。

## 関連ケース

- `case-01_standard-full-workflow.md`（単一言語プロジェクト）
- `case-06_sql-dialect-unknown.md`（SQL 方言の判定）
