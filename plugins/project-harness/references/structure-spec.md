# .claude ハーネス構成仕様（SSOT）

`project-harness` プラグインが対象プロジェクトに構築・維持する `.claude` フォルダ構成の単一情報源。
`harness-init` / `harness-update` の両スキルはこの仕様に従って生成・更新を行う。
ドキュメントの書き方・索引維持・検証の共通規則は [authoring-spec.md](authoring-spec.md)、同期の仕組みは [sync-spec.md](sync-spec.md) が保有する。

## 1. 目的（ハーネスエンジニアリング）

AI エージェントが対象プロジェクトで自律的・正確に働くための足場（ハーネス）を文書体系として整備する。

| 要素 | 役割 | 対応フォルダ |
|------|------|-------------|
| 地図 | プロジェクトの全体像・どこに何があるか | `CLAUDE.md` / `architecture/` / `specs/` / `flows/` |
| 検証手段 | 変更を自己検証するコマンド・手順 | `environments/` |
| ルール | 出力をプロジェクト標準に揃える規約 | `conventions/` |
| 判断履歴 | 既存判断の背景・用語の統一 | `decisions/` / `glossary.md` |
| 実装知識 | 仕様に対応する設計の詳細 | `system-designs/` |

## 2. ディレクトリ構成

```text
<target-repo>/
├── CLAUDE.md                  # ハーネス入口（節 4.1。既存があれば整理、無ければ最小スタブを作成）
└── .claude/
    ├── CLAUDE.md              # プロジェクト概要・技術スタック（常時読込・簡潔に保つ）
    └── references/
        ├── CLAUDE.md          # references/ 直下の一覧・用途・ドキュメント整理ルール
        ├── .sync-state.json   # 同期状態（sync-spec.md 参照）
        ├── requirements/      # 任意（節 2.1）。spec-first 運用時に harness-define が生成
        │   ├── CLAUDE.md      # 配下ファイルの一覧・用途
        │   └── *.md           # 要件定義書
        ├── specs/
        │   ├── CLAUDE.md      # 配下ファイルの一覧・用途
        │   └── *.md           # 仕様設計書
        ├── system-designs/
        │   ├── CLAUDE.md
        │   └── *.md           # 詳細設計書
        ├── flows/
        │   ├── CLAUDE.md
        │   └── *.md           # 画面位置・アクセス手順
        ├── environments/
        │   ├── CLAUDE.md
        │   └── *.md           # ビルド・テスト・起動・検証コマンド
        ├── conventions/
        │   ├── CLAUDE.md
        │   └── *.md           # コーディング規約・命名・配置・コミット/PR 規約
        ├── architecture/
        │   ├── CLAUDE.md
        │   └── *.md           # システム構成・モジュール依存・データモデル
        ├── decisions/
        │   ├── CLAUDE.md
        │   └── ADR-NNN_*.md   # 設計判断記録
        └── glossary.md        # ドメイン用語集（単一ファイル）
```

### 2.1 必須構成と任意構成

| 区分 | 対象 | 扱い |
|------|------|------|
| 必須 | `specs/` / `system-designs/` / `flows/` / `environments/` / `conventions/` / `architecture/` / `decisions/` / `glossary.md` | すべてのハーネスが持つ。`harness-update` の仕様バージョン照合（[sync-spec.md](sync-spec.md) 節 5）で不足時に補完提案の対象となる |
| 任意 | `requirements/` | spec-first 運用（`harness-define` によるプログラム実態がない状態からの要件定義・仕様先行作成）時に生成する。**仕様バージョン照合での補完提案の対象外**（コードから逆生成できないため、code-first で構築された既存ハーネスに空フォルダを増やさない）。code-first のハーネスへ後から追加してもよい（`harness-define` で要件定義を追加する場合） |

## 3. 各フォルダの定義

| フォルダ | 内容 | ファイル粒度 |
|---------|------|-------------|
| `requirements/`（任意） | 要件定義書（背景・目的・スコープ・機能要求・非機能要求・制約前提）。機能要求と `specs/` 配下の仕様設計書の対応表を持ち、要求から仕様へのトレーサビリティを保つ | 初期は `requirements.md` 1 ファイル。要求分類・サブシステム単位で分割してよい |
| `specs/` | 画面遷移・画面構成・業務ルール・アプリ動作まで踏み込んだ仕様設計書 | 機能・画面単位で 1 ファイル |
| `system-designs/` | `specs/` の仕様に対応した詳細設計書。実装において詳細化すべき設計情報（クラス構成・処理フロー・データアクセス・例外方針） | 対応する spec 単位で 1 ファイル |
| `flows/` | アプリ・サイトの画面位置とアクセス手順（URL・ナビゲーション経路・到達前提条件・権限） | 業務フロー・導線単位で 1 ファイル |
| `environments/` | ビルド・テスト・リント・起動・デプロイのコマンドと手順、環境変数、ローカル環境構築、デバッグ方法 | 環境・用途単位（例: `local-dev.md` / `test.md` / `ci-cd.md`） |
| `conventions/` | コーディング規約・命名規則・ファイル配置規則・コミット / PR 規約 | 規約分類単位 |
| `architecture/` | システム構成図・モジュール依存関係・データモデル（mermaid 図解を推奨） | 視点単位（例: `overview.md` / `data-model.md`） |
| `decisions/` | ADR（Architecture Decision Record）。採用した技術・構造の背景と理由 | 判断 1 件 = 1 ファイル（`ADR-NNN_<slug>.md`、NNN は 001 からの連番） |
| `glossary.md` | ドメイン用語・ユビキタス言語の定義 | 単一ファイル |

## 4. CLAUDE.md 階層索引規則（段階的開示）

コンテキスト効率のため、情報は「常時読込される最小限の入口 → 必要時に辿る詳細」の階層で整理する。

| ファイル | 記載内容 | 制約 |
|---------|---------|------|
| `.claude/CLAUDE.md` | プロジェクト概要・技術スタック・主要コマンド要約・`references/` への案内 | 常時読込される入口のため **100 行以内** を目安に簡潔に保つ。詳細は書かず `references/` へ誘導する |
| `references/CLAUDE.md` | フォルダ一覧・用途・ドキュメント整理ルール（どの情報をどこに置くか） | フォルダ単位の案内に留め、個別ファイルには踏み込まない |
| 各サブフォルダの `CLAUDE.md` | 配下ファイルの一覧・用途の表 | ファイル実体と一覧の一致を常に維持（[authoring-spec.md](authoring-spec.md) 節 3） |

### 4.1 ルート CLAUDE.md からの到達保証（必須）

`.claude/CLAUDE.md` が読み込まれるかは利用者の Claude Code 設定・バージョンに依存しうるため、
**リポジトリルートの `CLAUDE.md` から import 記法で明示的に参照** して到達性を保証する。

| 状況 | 動作 |
|------|------|
| ルート `CLAUDE.md` が無い | 以下の最小スタブを新規作成する（ユーザ承認のうえ実施） |
| ルート `CLAUDE.md` が既存 | 既存内容を残したまま、先頭または末尾に import 行 1 行を追記する（ユーザ承認のうえ実施） |

最小スタブの内容:

```markdown
# <project-name>

プロジェクトの概要・技術スタック・ドキュメント体系は `.claude/CLAUDE.md` を参照する。

@.claude/CLAUDE.md
```

| 規則 | 内容 |
|------|------|
| 参照方法 | `@.claude/CLAUDE.md` の import 記法を使う |
| 禁止 | 「詳細は .claude/CLAUDE.md を参照」等の **散文だけのポインタ**（読み込みが保証されない） |
| 既存内容の扱い | 既存の記述を削除・要約しない（追記のみ。整理が必要な場合は個別にユーザ承認を得る） |

### 4.2 他ツール・他プラグインとの相互運用

`.claude/references/conventions/` 等のハーネス配下ドキュメントは、リポジトリルートの `CLAUDE.md` のみを走査する外部ツールからは参照されない。
主要な規約・技術スタックの要約は `.claude/CLAUDE.md` に残し、節 4.1 の import で入口から到達できる状態を維持する。

## 5. frontmatter 規則

`references/` 配下の各ドキュメント（`CLAUDE.md` と `.sync-state.json` を除く）は、先頭に以下の frontmatter を持つ。

```yaml
---
title: <ドキュメント名>
sources:
  - <対応するソースコードパスのグロブ（リポジトリルート相対）>
related:
  - <関連ドキュメントの references/ 相対パス（任意）>
status: <draft | agreed | implemented（任意。節 5.2）>
updated: <YYYY-MM-DD>
---
```

| フィールド | 必須 | 用途 |
|-----------|------|------|
| `title` | 必須 | ドキュメント名（インデックス表と一致させる） |
| `sources` | 必須 | このドキュメントが対応するソースパスのグロブ。`harness-update` の差分検出キー（節 5.1）。ソース対応がない文書（用語集等）と **未実装の仕様ドキュメント** は `[]` |
| `related` | 任意 | spec ↔ system-design ↔ flow ↔ requirements の相互参照 |
| `status` | 任意 | 仕様ライフサイクル状態（節 5.2）。**不在時は `implemented` とみなす**（1.1 以前のハーネスとの後方互換） |
| `updated` | 必須 | 最終更新日 |

### 5.1 sources のグロブ記法（差分検出の契約）

`sources` は `harness-update` が変更ファイルと照合する唯一のキーであり、記法を揺らすと反映漏れ（取りこぼし）や過剰反応（ノイズ）が発生する。以下の記法に統一する。

| 規則 | 内容 |
|------|------|
| 基準 | リポジトリルート相対。先頭 `/` と `./` は付けない（`src/auth/**` であり `/src/auth/**` ではない） |
| 区切り | `/` のみを使う（Windows 環境でも `\` は使わない） |
| `*` | 単一階層内の 0 文字以上にマッチする（`/` にはマッチしない） |
| `**` | 0 階層以上の任意の深さにマッチする（`src/**/*.ts` は `src/a.ts` と `src/x/y/a.ts` の両方にマッチ） |
| 末尾 `/` | ディレクトリ配下全体を指す。`src/auth/` は `src/auth/**` と等価として扱う |
| 拡張子なしのパス | ファイル実体を指す（`src/auth/login.ts`）。ディレクトリを指す意図なら末尾 `/` を付ける |
| エントリ数 | 1 ドキュメントあたり **5 エントリ以内** を目安とする。超える場合は共通の親ディレクトリでまとめるか、ドキュメントの分割を検討する |

粒度の指針:

| 生成先 | 推奨する粒度 | 例 |
|-------|-------------|---|
| `specs/` / `flows/` | 機能・画面を構成するディレクトリ、または具体ファイル群 | `src/features/login/**` |
| `system-designs/` | 対応する spec と同一、または実装ファイル群 | `src/features/login/**`、`src/api/auth/**` |
| `architecture/` | レイヤ・モジュール境界のディレクトリまで（個別ファイルまで下げない） | `src/domain/**`、`src/infrastructure/**` |
| `environments/` | 設定ファイルの実体 | `package.json`、`docker-compose.yml`、`.github/workflows/**` |
| `conventions/` | 規約の根拠となる設定ファイル | `.editorconfig`、`eslint.config.js` |
| `requirements/` / `glossary.md` / 根拠ファイルのない `decisions/` | `[]`（差分検出の対象外。整合確認は全量監査モードで行う。[sync-spec.md](sync-spec.md) 節 4） | `[]` |
| 未実装の仕様ドキュメント（`status: draft` / `agreed`。節 5.2） | `[]`（対応ソースが未存在のため。実装追随（[sync-spec.md](sync-spec.md) 節 2）で実パスへ更新する） | `[]` |

### 5.2 status による仕様ライフサイクル管理

spec-first 運用（実装より先に仕様を書く）のために、frontmatter の任意フィールド `status` でドキュメントのライフサイクル状態を表す。

| 値 | 意味 |
|----|------|
| `draft` | 作成中・未合意（`harness-define` が生成した直後の状態） |
| `agreed` | ユーザとの合意済み・実装待ち |
| `implemented` | 実装済み（`sources` に実装パスを紐付け済み） |
| （不在） | `implemented` とみなす。1.1 以前のハーネス・code-first で生成したドキュメント・用語集や ADR 等の実装非依存ドキュメントは `status` を書かないことで自動的に実装追随の対象外となる |

| 規則 | 内容 |
|------|------|
| `draft` と `agreed` の差 | 同期動作（[sync-spec.md](sync-spec.md) 節 2 の実装追随）はどちらも同じ「未実装」として扱う。両者の差は **人間向けの合意状態表示** であり、同期の挙動に影響しない |
| `sources` との関係 | `draft` / `agreed` のドキュメントは原則 `sources: []`。実装が段階的に進む場合、確認できた分だけ `sources` を部分設定した `agreed` を許容する（全対応の紐付け完了と乖離確認を経てから `implemented` へ昇格する） |
| 合意ベースの明示 | `draft` / `agreed` のドキュメントは、記載の根拠が実装検証を経ていないことを本文冒頭の定型注記で明示する（[authoring-spec.md](authoring-spec.md) 節 1.1） |
| 昇格時の扱い | `implemented` へ昇格する際は `status` フィールドを削除せず `implemented` に書き換える（削除し忘れとの区別を保つ） |

状態遷移:

| 遷移 | 契機 |
|------|------|
| （新規）→ `draft` | `harness-define` がドキュメントを生成 |
| `draft` → `agreed` | `harness-define` の合意確認でユーザが承認 |
| `draft` / `agreed` → `implemented` | `harness-update` の実装追随（[sync-spec.md](sync-spec.md) 節 2）。`sources` の設定とセットで、ユーザ承認のうえ実施 |
| `implemented` → `draft` | 仕様変更で再設計へ入る場合（ユーザ指示による差し戻し） |
| `agreed` → `draft` | 合意の差し戻し（ユーザ指示） |

## 6. 命名規則

| 対象 | 規則 | 例 |
|------|------|---|
| ドキュメントファイル | kebab-case | `login-screen.md` |
| ADR | `ADR-NNN_<slug>.md` | `ADR-001_use-postgresql.md` |
| spec と system-design の対応 | 同名を推奨 | `specs/login-screen.md` ↔ `system-designs/login-screen.md` |

### 6.1 アーカイブ規則

対応ソースが削除される等でドキュメントが現行仕様でなくなった場合、ユーザ承認のうえ以下のいずれかで整理する。

| 扱い | 動作 |
|------|------|
| 削除 | ファイルを削除し、所属フォルダの `CLAUDE.md` 索引から該当行を除去する |
| アーカイブ | 所属フォルダ内の `archive/` サブフォルダへ移動し、frontmatter の `sources` を `[]` に変更する。索引 `CLAUDE.md` では通常一覧と分けた「アーカイブ」表に記載する |
| 保持 | 現状のまま残す（歴史的経緯の参照価値がある場合）。索引の内容説明に「対応ソース削除済み」と注記する |

`archive/` 配下のドキュメントは `harness-update` の差分照合対象から除外される（`sources: []` のため）。
ソースの **移動（rename）** は削除ではないため本規則の対象外とし、[sync-spec.md](sync-spec.md) 節 2 の「ソース移動」分類で `sources` を追随させる。

## 7. 既存資産との整合

| 状況 | 動作 |
|------|------|
| リポジトリルートに `CLAUDE.md` が既存 | 内容を `.claude/CLAUDE.md` と `references/` 配下へ取り込み、ルート側には節 4.1 の import 行を追記する（既存記述の削除・要約はユーザ承認時のみ） |
| リポジトリルートに `CLAUDE.md` が無い | 節 4.1 の最小スタブをユーザ承認のうえ作成する |
| `docs/` 等の既存ドキュメントが存在 | 取り込み候補としてユーザに提示。取り込む場合も **元ファイルは変更しない**（コピー・要約のみ） |
| `.claude/references/` が既存 | `harness-init` は再構築確認（保持マージ / 退避 / 破棄）、`harness-update` は節 9 の仕様バージョン照合で不足構成を補完する |

## 8. 大規模・モノレポ対応

1 フォルダのファイル数が **30 件** を超える場合、またはワークスペース定義（`pnpm-workspace.yaml` / `lerna.json` / 複数の `*.sln` 等）を検出した場合、パッケージ単位の 1 階層のみサブ名前空間を許容する。

```text
references/specs/
├── CLAUDE.md              # パッケージ一覧（この階層ではパッケージ単位の案内に留める）
├── <package-a>/
│   ├── CLAUDE.md          # 配下ファイルの一覧・用途
│   └── *.md
└── <package-b>/
    ├── CLAUDE.md
    └── *.md
```

| 規則 | 内容 |
|------|------|
| 深さ | サブ名前空間は **1 階層まで**（`specs/<package>/<feature>.md`）。2 階層以上は作らない |
| 索引 | 親 `CLAUDE.md` はパッケージ一覧、各パッケージの `CLAUDE.md` がファイル一覧を持つ 2 段構成 |
| 適用単位 | フォルダごとに独立して判断してよい（`specs/` のみ階層化し `architecture/` は平坦、も可） |
| `.claude/CLAUDE.md` | モノレポではパッケージ一覧と各パッケージの技術スタック要約に絞り、100 行以内を維持する |

## 9. 仕様バージョンと拡張手順

`.sync-state.json` の `harness_spec_version`（[sync-spec.md](sync-spec.md) 節 1）が、そのハーネスがどの版の本仕様で構築されたかを示す。現行版は **1.2**。

`harness_spec_version` が指すのは **本ファイル（structure-spec.md）の版のみ** である。[authoring-spec.md](authoring-spec.md) / [sync-spec.md](sync-spec.md) はプラグイン側の実行時仕様であり生成物に構造として埋め込まれないため、版を持たない。

### 9.0 版履歴と任意要素

| 版 | 追加内容 |
|----|---------|
| 1.2 | frontmatter `status` フィールド（節 5.2）・`requirements/` フォルダ（節 2.1）・骨格生成順序の共通化（節 10）。**いずれも任意要素**（下記） |
| 1.1 | アーカイブ規則・sources グロブ記法の明確化ほか |
| 1.0 | 初版 |

**任意要素**: `status` フィールドと `requirements/` フォルダは「あってもなくても正しいハーネス」として扱う任意要素であり、[sync-spec.md](sync-spec.md) 節 5 のマイナー移行における **補完提案の対象外** とする（既存の code-first ハーネスに不要なフィールド・空フォルダを増やさないため）。任意要素は spec-first 運用（`harness-define`）で利用するときに初めて生成される。

### 9.1 フォルダ種別を追加する場合の更新対象

新しいフォルダ種別・テンプレートを追加する際は、以下をすべて更新する（片方だけの更新を防ぐためのチェックリスト）。

- [ ] 本ファイル 節 2（ディレクトリ構成ツリー）と節 2.1（必須 / 任意の区分）
- [ ] 本ファイル 節 3（フォルダ定義表）
- [ ] 本ファイル 節 5.1（`sources` の粒度指針）
- [ ] `templates/` に雛形を追加し、`templates/CLAUDE.md` のファイル一覧へ登録
- [ ] `templates/claude-md-references.md`（生成される索引の雛形）のフォルダ一覧
- [ ] 本ファイル 節 9 冒頭の現行版と節 9.0（版履歴・任意要素）を繰り上げ
- [ ] `sync-spec.md` 節 1 の `.sync-state.json` 例示（`harness_spec_version` の値）
- [ ] `skills/harness-init/references/procedures.md` Phase 5 の初期化 JSON 例（`harness_spec_version` の値）
- [ ] `references/README.md`（人間向けインデックス）の構成表

### 9.2 仕様バージョン改定時の移行

| 改定内容 | バージョン | 既存ハーネスへの移行 |
|---------|-----------|-------------------|
| 必須のフォルダ種別・frontmatter フィールドの追加 | マイナー繰り上げ（例: 1.1 → 1.2） | `harness-update` が不足構成を検出し、ユーザ承認のうえ補完する（[sync-spec.md](sync-spec.md) 節 5） |
| **任意要素**（任意フォルダ・任意フィールド。節 9.0）の追加 | マイナー繰り上げ | **補完しない**（存在しなくても正しいハーネスのため）。`harness-update` は版数の追随のみ行う |
| 既存フォルダ・既存フィールドの意味変更・破壊的変更 | メジャー繰り上げ（1.x → 2.0） | `harness-init` の再構築（保持マージ）で移行する。`harness-update` は移行不可である旨を報告する |

## 10. 骨格生成順序（harness-init / harness-define 共通）

ハーネスの骨格（フォルダ・索引・入口・同期状態）を新規生成する際の順序と規則。`harness-init`（コード解析ベース）と `harness-define`（対話・資料ベース）の両スキルが共通で従う。**本節を共通規則とし、各スキルの `procedures.md` には生成内容（何をどの根拠で書くか）などスキル固有の手順のみを置く**（二重定義の禁止）。

1. フォルダ作成: `references/{specs,system-designs,flows,environments,conventions,architecture,decisions}/`（必須構成。`requirements/` は spec-first 運用時のみ追加。節 2.1）
2. 葉のドキュメント生成: [templates/](templates/) の雛形から生成し、`{...}` プレースホルダを全置換する
3. 各フォルダの `CLAUDE.md` 索引生成（ファイル実体と一致させる）
4. `references/CLAUDE.md` 生成
5. `.claude/CLAUDE.md` 生成（100 行以内）
6. `.sync-state.json` 初期化（[sync-spec.md](sync-spec.md) 節 1。`harness_spec_version` は節 9 の現行版）
7. gitignore 検査（2 段階。いずれも `.claude/` 外への書き込みのためユーザ承認必須・非対話モードでは報告のみ）:
   - `git check-ignore -q .claude/CLAUDE.md` でハーネス本体が無視されていないか。無視されている場合は `!.claude/CLAUDE.md` / `!.claude/references/` の否定パターン追加を提案（拒否時は「ローカル専用ハーネスとなりチームで同期状態を共有できない」旨を報告に明記）
   - `.claude/.local/` が `.gitignore` に含まれるか。含まれない場合は追記を提案
8. ルート `CLAUDE.md` の到達性確保（節 4.1。ユーザ承認必須・非対話モードでは報告のみ）

部分的既存（一部フォルダ・ファイルが存在する）の場合、既存部分は保持して不足分のみ生成する（既存ファイルの上書きは個別にユーザ承認を得る）。

## 11. 記載品質

ドキュメントの書き方（根拠主義・秘匿値の非記載・`TODO:` の扱い・図解・粒度）と、索引維持・検証の共通規則は [authoring-spec.md](authoring-spec.md) が保有する。
