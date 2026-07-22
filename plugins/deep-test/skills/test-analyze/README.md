<!-- TEST-ANALYZE-README-SENTINEL-v1 -->
# test-analyze スキル

deep-test プラグインの Phase 1.5（ソース理解 → 材料生成）を担うスキル。テスト対象ソースを read-only で静的に理解し、下流スキルが消費するテスト対象理解の材料を生成する。
生成する材料は機械可読の `analysis.yaml` と人間可読の `target-analysis.md` の 2 つで、後段の test-design がこれを材料にテストレベル / 技法 / 優先度 / ケースを決定する。本スキルは**決定の直前で止まる**（材料生成に徹し、決定はしない）。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 導入手順

本スキル `test-analyze` は `deep-test` プラグインに同梱されており、**追加インストールは不要**です。プラグインの導入手順（マーケットプレイス登録・インストール・自動更新の設定）は [`deep-test` プラグインの README](../../README.md) を参照してください。

- **起動トリガー**: オーケストレータ `test` の Phase 1.5（analyze フェーズ）からの委譲、または「このリポジトリのテスト対象を解析して」等の自然言語依頼での単独起動

## 何をするか

| ステップ | 内容 |
|---------|------|
| アーキ・依存把握 | 言語 / フレームワーク / レイヤー / ビルド基盤・依存グラフ・エントリポイント（HTTP ルート / API / CLI / メッセージ購読 / スケジュールジョブ / UI 画面 / 公開関数）を抽出 |
| ホットスポット特定 | 循環的複雑度（計測ツール有時のみ）× git churn で高リスク Top N を特定。ツール無しは `measured: false` で誠実に記録 |
| テスタビリティ評価 | DI 欠如 / グローバル状態 / 隠れ I/O / 非決定性 / 時刻結合と seam 候補を検出 |
| リスクレジスタ算出 | likelihood（複雑度 / churn / 外部依存）× impact（露出 / 業務重要度）で product risk を算出し、ISO/IEC 25010:2023 の 9 品質特性をマッピング |
| 攻撃面・カバレッジ観点 | 公開 EP・信頼境界から STRIDE 6 分類の静的所見、必要網羅基準と計測コマンド案（提案のみ・実測しない） |
| 縮退動作 | `source_availability`（full / partial / none）でソース不在時に縮退。推定は `confidence: low`、欠落は `open_questions` に記録（捏造しない） |
| 自己チェック | source-analyst エージェントで材料の網羅性・根拠妥当性・誠実性を単独レビューし、重大指摘を反映 |

## 使い方

### トリガーフレーズ例

```
このリポジトリのテスト対象を解析して
テスト設計の前に解析材料を作って
このアプリのテスト対象のリスクを洗い出して
diff=main..feature/x の変更影響を解析して
```

### 起動経路

| 経路 | 説明 |
|------|------|
| test オーケストレータ経由 | フルフローの Phase 1.5（analyze フェーズ）として Skill ツール経由で委譲される |
| 単独起動 | 上記トリガーフレーズで本スキルのみを直接実行する |

### 引数

| 引数 | 内容 |
|------|------|
| `対象説明=` | テスト対象（アプリ URL・リポジトリパス・対象名） |
| `spec=<パス>` | 仕様書（ファイルまたはディレクトリ）。指定時のみ仕様乖離検出（spec_divergence）を実施 |
| `diff=<git ref/範囲>` | 変更影響分析の対象差分。指定時のみ change_impact を算出 |
| `target-slug=<slug>` | 解決済み slug（委譲時にオーケストレータが渡す） |
| `base=<パス>` | 基準ディレクトリ（委譲時に受領） |
| `--non-interactive` | 非対話モード |

## 動作例

入力: 「このリポジトリのテスト対象を解析して。仕様書は docs/spec.md」

1. リポジトリを Glob / Grep で走査し、`source_availability: full` と対象種別（例: web-app）を判定
2. アーキ・エントリポイント・依存グラフ・既存テスト資産を抽出
3. `git log` の churn 集計 + 複雑度ツール（あれば radon / lizard）でホットスポット Top N を特定
4. リスクレジスタ（likelihood × impact）・攻撃面（STRIDE）・品質特性（ISO 25010:2023）・カバレッジ観点を材料化
5. `docs/spec.md` と主要ルートを粗く突合し spec_divergence を記録
6. `{target-slug}/analysis.yaml` と `{target-slug}/target-analysis.md` を生成
7. source-analyst の自己チェック → 指摘反映 → 解析結果サマリを返却

## 出力

- `{target-slug}/analysis.yaml` — 機械可読の材料（下流スキルが単方向に消費する SSOT。スキーマは plugin references の `yaml-schema-analysis.md`）
- `{target-slug}/target-analysis.md` — 人間可読のアーキ概要 + 依存グラフ（mermaid）+ EP 一覧 + ホットスポット Top N + テスタビリティ所見 + リスク + 品質特性 + 推奨事項（提案）
- 解析結果サマリ（対象種別・source_availability・セクション別件数・source-analyst 所見・open_questions）

配置規約は plugin references の `data-locations.md`。`test-results.yaml` には一切書き込まない。

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| analysis.yaml のフィールド・enum・ID 形式を追加 / 変更する | plugin references の `yaml-schema-analysis.md`（唯一の SSOT）を改訂する。本スキルは参照のみ |
| 解析手順（対象種別判定・churn 取得・縮退の詳細）を調整する | `references/procedures.md` |
| 自己チェックの起動フェーズ・エージェント構成を変更する | `references/agents.md` と plugin references の `agents.md` |
| 複雑度計測ツールを追加する | SKILL.md frontmatter の `allowed-tools` にコメントアウト済みの `Bash(radon *)` / `Bash(lizard *)` を有効化し、`procedures.md` の計測手順に追記する |

## ファイル構成

```
plugins/deep-test/skills/test-analyze/
├── SKILL.md                  # Claude が実行時に読むスキル定義（200 行以下）
├── README.md                 # 本ファイル（人間向け）
├── references/
│   ├── procedures.md         # 入力解決 → 縮退判定 → 材料生成 → 自己チェックの詳細手順
│   └── agents.md             # フェーズ定義（source-analyst の起動フェーズ）
└── evals/                    # 動作分岐検証ケース（case-01〜15 + README・15 ケース）
```

> Python は既定で同梱しない（環境構築 setup 不要）。カバレッジ実測は行わず計測コマンドの提案に留め、churn は git 読み取り、複雑度は存在する read-only ツールのみで計測する（無ければ `measured: false`）。将来、複雑度 × churn の決定的集計や analysis.yaml の機械検証が必要になった場合に限り `scripts/setup/`（venv）を追加する。

## スコープ外

- テストケース設計・テストレベル / 技法 / 優先度の決定・テスト計画（test-plan.md）の生成（`test-design` が担当。本スキルは材料生成まで）
- テストの実行・カバレッジの実測（`test-run-*`。本スキルは計測コマンドの提案まで）
- 成果物のレビュー・承認（`test-review`）・実績記録 / 報告書（オーケストレータ `test` / `test-report`）
- 稼働アプリへの動的探索・動的セキュリティ検査（`test-run-*` / `test-setup`）

## 関連スキル

- `test` — オーケストレータ（Phase 1.5 の委譲元）
- `test-setup` — Phase 1。検出したランナー・複雑度 / カバレッジツール情報の供給元
- `test-design` — Phase 2。analysis.yaml を材料にレベル / 技法 / 優先度 / ケースを決定する消費先
