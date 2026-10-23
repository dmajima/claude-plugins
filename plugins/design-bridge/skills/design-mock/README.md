# design-mock

Markdown の画面設計書を入力に、トンマナ（`_tokens.html`）と基礎レイアウト（`_layout.html`）に準拠した画面モック HTML を生成するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` を参照してください。

## 責務（要約）

- トンマナ（デザイントークン）と基礎レイアウトの雛形を生成する
- 画面設計書の記述から画面モック HTML を生成する
- 生成した HTML に `@dsCard` マーカーを付与する
- 生成結果を未反映として記録し、`design-push` へ繋ぐ

生成までが責務です。スクリーンショットの生成と claude.ai/design への反映は `design-push` が担当します。設計書（Markdown）本文の執筆はユーザまたは通常の編集作業の領分です。

## なぜモックを「ローカルの正本」として生成するのか

Markdown の画面設計書だけでは画面イメージが伝わりません。かといって claude.ai/design 上で直接モックを作ると、設計書・モック・実装のどれかを直した瞬間に三者が乖離します。`DesignSync` にはリモート変更の通知機構（watch）がないため、claude.ai/design 側で加えた変更をセッション中に検知することは原理的にできず、「承認したカード」と「正本の設計書」が静かにずれていきます。

design-bridge はこれを、正本をローカルに固定することで防ぎます。

| 原則 | `design-mock` での現れ方 |
|------|----------------------|
| 正本は `mocks/` の HTML | モックは必ずローカルに生成する。claude.ai/design 側で作らない |
| 設計書が入力、モックが出力 | 設計書に書かれていない機能・項目・文言を創作しない |
| 見た目の一貫性はトンマナで担保 | 画面ごとに独自の色やサイズを導入せず、`_tokens.html` のトークンを参照する |
| 生成したら必ず反映する | 生成パスを未反映として記録し、Stop フックが `design-push` を促す |

外部 CDN に依存しないという制約も同じ理由によるものです。claude.ai/design 上での表示とオフラインでの閲覧の両方で、同じ見た目が再現される必要があります。

## 使い方

### 前提

1. `.claude/design-bridge.json` が存在すること（未導入なら先に `design-init`）
2. 対象画面の Markdown 設計書が `specsDir` にあること（トンマナ・基礎レイアウトの生成時は不要）

### トリガーフレーズ例

- 「ログイン画面のモックを作って」
- 「設計書からモックを起こして」
- 「トンマナを作って」「基礎レイアウトを用意して」
- `/design-mock S001_login`
- `/design-mock --tokens` / `/design-mock --layout`

### 入力 → 出力の流れ

1. 引数または対話で対象画面を決める（`specsDir` に対応する Markdown が無ければ設計書の用意を促す）
2. `mocksDir/_tokens.html` と `mocksDir/_layout.html` の有無を確認する（無ければ先に生成してよいか確認する）
3. 対象の Markdown から、画面名・画面 ID・表示項目・操作と遷移先・バリデーション・状態を読み取る
4. `mocksDir/<画面 ID>.html` を生成する（先頭行に `@dsCard` マーカー、トンマナのトークンを参照、`_layout.html` の骨格に沿う）
5. 生成・更新したパスを未反映として記録する
6. 生成ファイル・踏襲したトンマナ・仮置きした箇所を報告し、`design-push` での反映を案内する

## 動作例

入力:

```text
/design-mock S001_login
```

出力:

```text
<repo>/mocks/S001_login.html
```

生成される HTML の先頭行は次の形になります（`group` は設計書の分類に合わせます）。

```html
<!-- @dsCard group="画面" -->
```

報告には、踏襲したトンマナと、設計書に記載が無く仮置きした箇所が明示されます。仮置きが残っている場合は、設計書側を直してから再生成するのが正しい直し方です（正本は設計書とモックであり、モックだけを場当たりに直すと乖離の起点になります）。

## 生成物と記録

| 対象 | パス | コミット |
|-----|------|---------|
| トンマナ | `<mocksDir>/_tokens.html` | 対象 |
| 基礎レイアウト | `<mocksDir>/_layout.html` | 対象 |
| 画面モック | `<mocksDir>/<画面 ID>.html` | 対象 |
| 未反映リスト | `.claude/.local/plugins/design-bridge/pending.tsv` | 対象外 |

未反映リストへの追記は通常 PostToolUse フックが自動で行います。フックが未適用の環境では、スキルが明示的に追記します。

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| モックの置き場・設計書の置き場 | `.claude/design-bridge.json` の `mocksDir` / `specsDir`（スキーマは `${CLAUDE_PLUGIN_ROOT}/skills/design-init/references/config-schema.md`） |
| 色・タイポグラフィ・余白・コンポーネント定義 | `<mocksDir>/_tokens.html` を編集（画面モック側には書かない） |
| 全画面共通の骨格 | `<mocksDir>/_layout.html` を編集 |
| カードのグルーピング | 生成 HTML 先頭の `@dsCard` マーカーの `group` 属性 |
| 反映時の手順 | `${CLAUDE_PLUGIN_ROOT}/skills/design-push/references/procedures.md` |

## 注意事項

- 既存のモック HTML を無確認で上書きしません
- トンマナを無視した独自スタイルを画面モックに持ち込みません
- 設計書に無い機能・項目は創作しません（仮置きする場合は必ず報告します）
- 外部 CDN への依存を持ち込みません（オフラインで開けること）
- スクリーンショットの生成は行いません（`design-push` の責務）
- 社内マーケットプレイス `customerep-claudecode` の `prod-asset-import` プラグインにある `design-sync` スキルは、本番サーバーからフロントリソースを取り込む別物です。名前が似ていますが本スキルとは無関係です

## 関連スキル

| スキル | 関係 |
|-------|------|
| `design-init` | 本スキルの前提となる `.claude/design-bridge.json` とディレクトリ構成を作る |
| `design-push` | 生成したモックのスクショを撮り、claude.ai/design へ反映する |
| `design-status` | 生成後に未反映として記録されたパスを確認する |
| `design-pull` | 明示指示時のみ、claude.ai/design 側の内容をローカルへ取り込む |

## ファイル構成

```text
skills/design-mock/
├── SKILL.md                      # スキル定義（Claude が実行時に読み込む）
├── README.md                     # 本ファイル（人間向け）
└── evals/
    ├── README.md
    └── case-*.md                 # 動作分岐の期待挙動
```
