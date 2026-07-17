# case-06 多言語モノレポの言語・FW 検出と観点プロファイル適用（C23 / O10）

TypeScript + React のフロントエンドと SQL マイグレーションが混在する差分を標準モードでレビューし、言語・FW 検出（Step 2）→ 観点プロファイルの委譲（Step 4 `language-profiles`）が正しく行われるケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをコードレビューして"（差分: `src/components/*.tsx` 12 ファイル + `src/styles/*.css` 3 ファイル + `migrations/*.sql` 2 ファイル。リポジトリルートに `tsconfig.json` + `package.json`（react / next 依存）+ `docker-compose.yml`（postgres イメージ）あり） |
| モード | 標準（コマンド `/code-review-standard` 経由で固定） |

## 分岐の根拠

references/flow/flow.md Step 2「言語・フレームワーク検出（必須）」、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 2（観点プロファイル対応表）・セクション 3（手順詳細）、skill-rules-matrix.md C23 / O10。

## 期待動作

- Step 2: 差分ファイルの拡張子から TypeScript（`.tsx`）・CSS・SQL を言語候補として列挙する
- Step 2: `tsconfig.json` が存在するため JavaScript ではなく **TypeScript プロファイル**（`languages/typescript.md`。javascript.md を継承）を選択する
- Step 2: `package.json` の依存（react / next）から `frameworks/react.md` を適用対象にする
- Step 2: `docker-compose.yml` の postgres イメージから SQL 方言を **PostgreSQL** と判定し、`languages/sql.md` を適用対象にする
- Step 2: 検出結果（主: TypeScript、副: CSS / SQL(PostgreSQL)、FW: React/Next.js）を「適用規約サマリ」に記録する
- Step 4: 観点別スキルへの委譲引数に `language-profiles=<適用プロファイルパス一覧>` を含める（flow.md Step 4 引数フォーマット）
- 観点別スキル: 受け取った `language-profiles` に基づき、各エージェントのプロンプトに言語プロファイル参照指示（common-references.md セクション 4.5 のテンプレート）を含める（O10）
- Step 8: 統合サマリの集計セクションに「検出言語・FW と適用観点プロファイル」を記載する（output-format.md セクション 1.4）
- （以下は検出してはならない誤り）
    - `tsconfig.json` があるのに JavaScript プロファイルを適用する
    - マーカーファイルを確認せずに拡張子だけで Next.js を断定する
    - 検出されなかった言語（例: PHP）のプロファイルを委譲引数に含める

## 関連ケース

- case-01: 標準モードの基本フロー（言語検出を含む Step 2 全体）
- case-07: 未対応言語を含む差分の扱い
