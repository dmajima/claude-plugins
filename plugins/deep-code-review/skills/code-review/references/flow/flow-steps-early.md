# レビュー実行フロー — 前半 Step（0-P〜3.5）

> 親: [flow.md](flow.md)（全体図・用語定義・Step 索引）。本ファイルは **準備〜動員決定フェーズ**（Step 0-P / Step 0 / Step 1 / Step 2 / Step 3 / Step 3.5）の詳細を保持。
> 続き: レビュー実行（Step 4〜7）は [flow-steps-review.md](flow-steps-review.md)、出力・状態（Step 8〜8.5）は [flow-steps-output.md](flow-steps-output.md)。

---

## Step 0-P: 事前準備（前回 state 読込・inputs 確認・コード信頼性原則）

開始前に前回状態と仕様情報を読み込む。

### 0-P-1: ブランチ名の確定

ブランチ名を `git branch --show-current` で取得。`pr-review` からの委譲時は PR のブランチ名を使う。

### 0-P-2: 前回 state.yaml の読み込み

`.claude/.local/plugins/deep-code-review/{branch_name}/` 配下のタイムスタンプフォルダを日時降順ソートし最新の `state.yaml` を検索。

| 結果 | 動作 |
|------|------|
| state.yaml あり | 読み込み、前回の findings / remaining_issues / ignored_by_user / code_as_reference_decisions を保持。`review_round` を +1 して今回の回数とする |
| state.yaml なし | 初回レビューとして扱う。`review_round: 1` で開始 |

### 0-P-3: inputs フォルダの確認

`.claude/.local/plugins/deep-code-review/{branch_name}/inputs/` の存在を確認する。

| 結果 | 動作 |
|------|------|
| inputs フォルダあり | 中身を読み込み、仕様情報として保持（Step 2 で活用） |
| inputs フォルダなし + `spec=<path>` 引数あり | 指定パスからファイルを読み込み、inputs フォルダを作成して保存 |
| inputs フォルダなし + `spec` 引数なし | `inputs-management.md` セクション 4 のヒアリングフローを実行。ユーザーが「仕様確認不要」と回答した場合はスキップ |

### 0-P-4: コード信頼性原則の適用準備

前回 state.yaml に `code_as_reference_decisions` があれば承認済みパターンを保持。新たにコードからの規約類推が必要なら `code-trustworthiness.md` に従いユーザー承認を取る。

詳細: `${CLAUDE_SKILL_DIR}/references/state/state-management.md` セクション 4 / `${CLAUDE_SKILL_DIR}/references/state/inputs-management.md` セクション 4 / `${CLAUDE_SKILL_DIR}/references/state/code-trustworthiness.md`。

---

## Step 0: モード選択

`AskUserQuestion` で **標準 / 簡易** の2段階から選択させる。

| モード | 動員観点別スキル | 内訳エージェント |
|--------|-----------------|-----------------|
| 標準 | 5種（impl / testing / security / architecture / frontend）。差分内容に応じて architecture / frontend は省略可 | 各スキル内のエージェント全員（最大10種） |
| 簡易 | 必須トリオ3種（impl / testing / security）のみ | 各スキル内のエージェント全員（最大7種：impl + linter + perf + test + runner + sec + dep） |

> **粒度に注意**: モード判断は **観点別スキル単位**でありエージェント単位ではない。簡易モードでも各観点別スキル内の補助エージェント（linter / perf 等）は通常通り動作する（観点別スキル内部で動的検証 SKIPPED 設計が機能する）。

**非対話モード・失敗時**: 標準モードで実行（既定）。詳細は `mode-selection.md`。

---

## Step 1: スコープ確定

対象範囲をユーザー指示・引数から特定。比較ブランチは **`origin/develop` → `origin/main` → `origin/master`** の順で自動判定（`scope-detection.md` セクション 1.2 参照）。

| ユーザー指示の例 | 解釈 | 取得方法 |
|---|---|---|
| 「このブランチをレビュー」 | カレントブランチ vs 自動判定の比較ブランチ | `git diff <自動判定>...HEAD` |
| 「○○.cs をレビュー」 | 指定ファイル全文 | `Read` |
| 「直近のコミット」 | `HEAD` の差分 | `git show HEAD` |
| 「ステージング済み」 | インデックスの差分 | `git diff --cached` |
| `pr-review` から委譲（`scope=pr-diff`） | PR 差分（差分・コンテキストは `pr-review` から渡される） | プロンプト引数に含まれる差分を使用 |

> **PR レビュー要求**（「PR #123 をレビュー」等）は **本スキルではなく `pr-review` スキルが起点**。本スキルが直接 `gh pr` コマンドを呼ぶことはない。

詳細は `scope-detection.md`。

---

## Step 2: 変更内容の把握＋プロジェクト規約読込

差分を確認し変更の **性質** を分類、プロジェクト規約を読み込む。

### ベンダーディレクトリの自動除外

変更ファイル一覧の取得後、以下のパスパターンに一致するファイルをレビュー対象から **自動除外**（NuGet パッケージ・npm モジュール等のサードパーティコードは対象外）:

| パターン | 対象 |
|---------|------|
| `/packages/**` | NuGet パッケージ（.NET Framework） |
| `/node_modules/**` | npm モジュール |
| `/**/bin/**` | ビルド出力 |
| `/**/obj/**` | ビルド中間出力 |
| `/**/.vs/**` | Visual Studio 設定 |
| `/**/bower_components/**` | Bower パッケージ |
| `/**/vendor/**` | Composer 等のベンダーディレクトリ |

除外ファイル数は統合サマリの集計セクションに「ベンダーディレクトリ除外: N 件」と記載する。除外対象にユーザーのカスタムコードが含まれる可能性があれば、除外前にユーザーに確認する。

### 分類軸

| 軸 | 観点 |
|----|------|
| 規模 | 数行 / 関数〜ファイル単位 / 複数ファイル / 設計レベル |
| 種別 | 機能追加 / バグ修正 / リファクタリング / 設定変更 / マイグレーション |
| ドメイン | フロントエンド / バックエンド / API / バッチ / DB / 設定 / 静的アセット 等 |
| 危険度 | 認証・決済・個人情報・外部公開 等の高リスク要素を含むか |

### 言語・フレームワーク検出（必須）

差分ファイル一覧とマーカーファイルから対象の言語・フレームワークを検出し、適用する観点プロファイルを確定。手順・対応表は **`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md`** に従う:

1. 差分ファイルを拡張子で言語分類（JS/TS は `tsconfig.json` 有無で分岐）
2. マーカーファイル（`package.json` / `*.csproj` / `composer.json` / `pyproject.toml` 等）の依存定義から FW を特定
3. SQL は方言（MySQL / SQL Server / PostgreSQL）を判定（判定不能なら共通観点のみ）
4. 適用する言語プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/*.md`）と FW プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/frameworks/*.md`）の一覧を確定
5. 観点プロファイルが無い言語は「未対応言語」として統合サマリの未確認事項に明示（推測規約で評価しない）

検出結果は「適用規約サマリ」（後述）に記録し、Step 4 / Step 4-T の委譲引数に含める。

### プロジェクト規約読み込み（必須）

| 探索対象 | 用途 |
|---------|------|
| `CLAUDE.md` / `.claude/CLAUDE.md` | プロジェクト全体の方針・規約 |
| `.claude/rules/**/*.md` | 細分化されたルール |
| `CONTRIBUTING.md` / `docs/` 配下 | コントリビューションガイド・スタイルガイド |
| `.editorconfig` / `.eslintrc*` / `.prettierrc*` 等 | 整形・Linter 設定 |

要約を **最大 2,000 文字** にまとめ `project-rules-summary` として保持。Step 4 / Step 4-T で観点別スキル / Agent Teams メンバーに渡す。

**規約源の優先順位解決**: プロジェクト規約と言語プロファイルのデファクト規約の優先順位は **`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md`**（5 段階解決）に従う。解決結果（言語・FW 検出結果 + 規約源の対応表）を「適用規約サマリ」として `project-rules-summary` に統合する。プロジェクト独自規約が存在する項目では、言語プロファイルのデファクトを根拠にした指摘を出さない。

### 仕様書読み込み（任意）

`spec=<path>` 引数指定時は仕様書ファイルを全文読み込み、最大 4,000 文字の `spec_summary` を生成し `code-review-implementation` に追加観点として渡す。

### inputs フォルダの読み込み（Step 0-P で準備済み）

Step 0-P-3 で読み込んだ inputs フォルダの内容を `spec_summary` に統合する。`spec=<path>` 引数指定の仕様書と inputs フォルダの内容が重複すれば inputs フォルダを優先する。

inputs の活用方法:
- 観点別スキルへの `args` に含める `spec_summary` に inputs の要約を統合
- 仕様整合性チェック（実装漏れ・仕様逸脱）の判断根拠として使用
- 統合サマリの集計セクションに参照した inputs ファイル一覧を記載

### コード信頼性原則の適用

変更内容の評価基準を策定する際は `code-trustworthiness.md` の原則に従う:
- **参照してよい情報源**: CLAUDE.md / `.claude/rules/` / `.editorconfig` / inputs フォルダ / OWASP 等
- **ユーザー承認が必要**: 差分外の既存コードパターンからの規約類推、提出コード内のパターンからの規約類推
- **参照禁止**: 提出コードのパターンを無断で規約として類推すること

### 出力（メモ）

- 変更ファイル一覧と各ファイルの 1 行要約
- 上記分類軸に対する判定
- **言語・フレームワーク検出結果と適用観点プロファイル一覧**（適用規約サマリに含める）
- 変更の意図（コミットメッセージ・PR 説明から推定）
- 採用した比較ブランチ（ユーザーに通知）
- 参照した規約ファイル一覧（集計セクションに記載）
- 参照した仕様書ファイル（指定時のみ）
- 参照した inputs ファイル一覧
- コード信頼性に関するユーザー承認結果（承認取得した場合）

---

## Step 3: 動員する観点別スキルの決定

Step 0 のモードと Step 2 の分類結果を組み合わせ、起動する **観点別スキル** を決定する。

### 簡易モード

| 動員 | 起動条件 |
|------|---------|
| `code-review-implementation` | 必須 |
| `code-review-testing` | 必須 |
| `code-review-security` | 必須 |

動的省略は行わない。`code-review-architecture` / `code-review-frontend` は起動しない。

### 標準モード

| 動員 | 起動条件 |
|------|---------|
| `code-review-implementation` | 必須 |
| `code-review-testing` | 必須 |
| `code-review-security` | 必須 |
| `code-review-architecture` | 設計影響 or DB 変更 がある場合（コメント追記等の単純変更のみなら省略） |
| `code-review-frontend` | HTML / CSS / JS / React（.jsx/.tsx）/ Vue / テンプレート（.cshtml/.razor/.blade.php/.liquid/.twig 等）/ 静的アセットの変更がある場合（変更なしなら省略） |

ユーザーが明示的に「フルレビュー」「全観点動員」を要求した場合は、上記の動的省略を適用せず標準モード全動員。

---

## Step 3.5: Agent Teams 採用判定

差分の主たる性質と規模に応じて、`team-selection.md` の **5パターン** から最適なものを選ぶ。

### 採用条件（いずれかを満たす）

- 標準モード かつ 大規模変更（10ファイル超 or 1,000行超）
- 標準モード かつ セキュリティクリティカル変更（認証/認可/決済/個人情報/外部公開API/OSS依存追加）
- 標準モード かつ 大規模設計変更
- 標準モード かつ DB スキーマ・マイグレーション変更
- 標準モード かつ 大規模UI/フロントエンド変更
- ユーザー明示要求（「議論して」「多角的に検討して」）

### フォールバック条件（サブエージェント方式へ）

- 簡易モード（`mode=quick`）
- 軽微変更（10ファイル未満 かつ 1,000行未満 かつ 単純変更）
- `TeamCreate` 利用不可
- 非対話モード
- ユーザーが却下
- `TeamCreate` がエラー

### ユーザー承認

採用候補が決まったら `AskUserQuestion` でユーザー承認を取る（コスト最大 6 倍程度を明示）。詳細は `team-selection.md` セクション 3.1。

---

> 続き: [flow-steps-review.md](flow-steps-review.md)（Step 4〜7） / 索引・全体図: [flow.md](flow.md)
